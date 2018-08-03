// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import 'ast/sass.dart';
import 'import_cache.dart';
import 'importer.dart';
import 'visitor/find_imports.dart';

/// A graph of the import relationships between stylesheets, available via
/// [nodes].
class StylesheetGraph {
  /// A map from canonical URLs to the stylesheet nodes for those URLs.
  Map<Uri, StylesheetNode> get nodes => new UnmodifiableMapView(_nodes);
  final _nodes = <Uri, StylesheetNode>{};

  /// The import cache used to load stylesheets.
  final ImportCache importCache;

  /// A map from canonical URLs to the time the corresponding stylesheet or any
  /// of the stylesheets it transitively imports was modified.
  final _transitiveModificationTimes = <Uri, DateTime>{};

  StylesheetGraph(this.importCache);

  /// Returns whether the stylesheet at [url] or any of the stylesheets it
  /// imports were modified since [since].
  ///
  /// If [baseImporter] is non-`null`, this first tries to use [baseImporter] to
  /// import [url] (resolved relative to [baseUrl] if it's passed).
  ///
  /// Returns `true` if the import cache can't find a stylesheet at [url].
  bool modifiedSince(Uri url, DateTime since,
      [Importer baseImporter, Uri baseUrl]) {
    DateTime transitiveModificationTime(StylesheetNode node) {
      return _transitiveModificationTimes.putIfAbsent(node.canonicalUrl, () {
        var latest = node.importer.modificationTime(node.canonicalUrl);
        for (var upstream in node.upstream.values) {
          // If an import is missing, always recompile so we show the user the
          // error.
          var upstreamTime = upstream == null
              ? new DateTime.now()
              : transitiveModificationTime(upstream);
          if (upstreamTime.isAfter(latest)) latest = upstreamTime;
        }
        return latest;
      });
    }

    var node = _add(url, baseImporter, baseUrl);
    if (node == null) return true;
    return transitiveModificationTime(node).isAfter(since);
  }

  /// Adds the stylesheet at [url] and all the stylesheets it imports to this
  /// graph and returns its node.
  ///
  /// If [baseImporter] is non-`null`, this first tries to use [baseImporter] to
  /// import [url] (resolved relative to [baseUrl] if it's passed).
  ///
  /// Returns `null` if the import cache can't find a stylesheet at [url].
  StylesheetNode _add(Uri url, [Importer baseImporter, Uri baseUrl]) {
    var tuple = _ignoreErrors(
        () => importCache.canonicalize(url, baseImporter, baseUrl));
    if (tuple == null) return null;
    return addCanonical(tuple.item1, tuple.item2, tuple.item3);
  }

  /// Adds the stylesheet at the canonicalized [canonicalUrl] and all the
  /// stylesheets it imports to this graph and returns its node.
  ///
  /// Returns `null` if [importer] can't import [canonicalUrl].
  ///
  /// If passed, the [originalUrl] represents the URL that was canonicalized
  /// into [canonicalUrl]. It's used as the URL for the parsed stylesheet, which
  /// is in turn used in error reporting.
  StylesheetNode addCanonical(Importer importer, Uri canonicalUrl,
      [Uri originalUrl]) {
    var stylesheet = _ignoreErrors(
        () => importCache.importCanonical(importer, canonicalUrl, originalUrl));
    if (stylesheet == null) return null;

    return _nodes.putIfAbsent(
        canonicalUrl,
        () => new StylesheetNode._(stylesheet, importer, canonicalUrl,
            _upstreamNodes(stylesheet, importer, canonicalUrl)));
  }

  /// Returns a map from non-canonicalized imported URLs in [stylesheet], which
  /// appears within [baseUrl] imported by [baseImporter].
  Map<Uri, StylesheetNode> _upstreamNodes(
      Stylesheet stylesheet, Importer baseImporter, Uri baseUrl) {
    var active = new Set.of([baseUrl]);
    var upstream = <Uri, StylesheetNode>{};
    for (var import in findImports(stylesheet)) {
      var url = Uri.parse(import.url);
      upstream[url] = _nodeFor(url, baseImporter, baseUrl, active);
    }
    return upstream;
  }

  /// Re-parses the stylesheet at [canonicalUrl] and updates the dependency graph
  /// accordingly.
  ///
  /// Throws a [StateError] if [canonicalUrl] isn't already in the dependency graph.
  ///
  /// Removes the stylesheet from the graph entirely and returns `null` if the
  /// stylesheet's importer can no longer import it.
  StylesheetNode reload(Uri canonicalUrl) {
    var node = _nodes[canonicalUrl];
    if (node == null) {
      throw new StateError("$canonicalUrl is not in the dependency graph.");
    }

    // Rather than spending time computing exactly which modification times
    // should be updated, just clear the cache and let it be computed again
    // later.
    _transitiveModificationTimes.clear();

    importCache.clearImport(canonicalUrl);
    var stylesheet = _ignoreErrors(
        () => importCache.importCanonical(node.importer, canonicalUrl));
    if (stylesheet == null) {
      remove(canonicalUrl);
      return null;
    }
    node._stylesheet = stylesheet;

    node._stylesheet = stylesheet;
    node._replaceUpstream(
        _upstreamNodes(stylesheet, node.importer, canonicalUrl));
    return node;
  }

  /// Removes the stylesheet at [canonicalUrl] from the stylesheet graph.
  ///
  /// Throws a [StateError] if [canonicalUrl] isn't already in the dependency graph.
  void remove(Uri canonicalUrl) {
    var node = _nodes.remove(canonicalUrl);
    if (node == null) {
      throw new StateError("$canonicalUrl is not in the dependency graph.");
    }

    // Rather than spending time computing exactly which modification times
    // should be updated, just clear the cache and let it be computed again
    // later.
    _transitiveModificationTimes.clear();

    importCache.clearImport(canonicalUrl);
    node._remove();
  }

  /// Returns the [StylesheetNode] for the stylesheet at the given [url], which
  /// appears within [baseUrl] imported by [baseImporter].
  ///
  /// The [active] set should contain the canonical URLs that are currently
  /// being imported. It's used to detect circular imports.
  StylesheetNode _nodeFor(
      Uri url, Importer baseImporter, Uri baseUrl, Set<Uri> active) {
    var tuple = _ignoreErrors(
        () => importCache.canonicalize(url, baseImporter, baseUrl));

    // If an import fails, let the evaluator surface that error rather than
    // surfacing it here.
    if (tuple == null) return null;
    var importer = tuple.item1;
    var canonicalUrl = tuple.item2;
    var resolvedUrl = tuple.item3;

    // Don't use [putIfAbsent] here because we want to avoid adding an entry if
    // the import fails.
    if (_nodes.containsKey(canonicalUrl)) return _nodes[canonicalUrl];

    /// If we detect a circular import, act as though it doesn't exist. A better
    /// error will be produced during compilation.
    if (active.contains(canonicalUrl)) return null;

    var stylesheet = _ignoreErrors(
        () => importCache.importCanonical(importer, canonicalUrl, resolvedUrl));
    if (stylesheet == null) return null;

    active.add(canonicalUrl);
    var node = new StylesheetNode._(stylesheet, importer, canonicalUrl,
        _upstreamNodes(stylesheet, importer, canonicalUrl));
    active.remove(canonicalUrl);
    _nodes[canonicalUrl] = node;
    return node;
  }

  /// Clears the cached canonical version of the given [url] in [importCache].
  ///
  /// Also resets the cached modification times for stylesheets in the graph.
  void clearCanonicalize(Uri url) {
    // Rather than spending time computing exactly which modification times
    // should be updated, just clear the cache and let it be computed again
    // later.
    _transitiveModificationTimes.clear();
    importCache.clearCanonicalize(url);
  }

  /// Runs [callback] and returns its result.
  ///
  /// If [callback] throws any errors, ignores them and returns `null`. This is
  /// used to wrap calls to the import cache, since importer errors should be
  /// surfaced by the compilation process rather than the graph.
  T _ignoreErrors<T>(T callback()) {
    try {
      return callback();
    } catch (_) {
      return null;
    }
  }
}

/// A node in a [StylesheetGraph] that tracks a single stylesheet and all the
/// upstream stylesheets it imports and the downstream stylesheets that import
/// it.
///
/// A [StylesheetNode] is immutable except for its downstream nodes. When the
/// stylesheet itself changes, a new node should be generated.
class StylesheetNode {
  /// The parsed stylesheet.
  Stylesheet get stylesheet => _stylesheet;
  Stylesheet _stylesheet;

  /// The importer that was used to load this stylesheet.
  final Importer importer;

  /// The canonical URL of [stylesheet].
  final Uri canonicalUrl;

  /// A map from non-canonicalized import URLs in [stylesheet] to the
  /// stylesheets those imports refer to.
  ///
  /// This may have `null` values, which indicate failed imports.
  Map<Uri, StylesheetNode> get upstream => new UnmodifiableMapView(_upstream);
  Map<Uri, StylesheetNode> _upstream;

  /// The stylesheets that import [stylesheet].
  Set<StylesheetNode> get downstream => new UnmodifiableSetView(_downstream);
  final _downstream = new Set<StylesheetNode>();

  StylesheetNode._(
      this._stylesheet, this.importer, this.canonicalUrl, this._upstream) {
    for (var node in upstream.values) {
      if (node != null) node._downstream.add(this);
    }
  }

  /// Sets [newUpstream] as the new value of [upstream] and adjusts upstream
  /// nodes' [downstream] fields accordingly.
  void _replaceUpstream(Map<Uri, StylesheetNode> newUpstream) {
    var oldUpstream = new Set.of(upstream.values)..remove(null);
    var newUpstreamSet = new Set.of(newUpstream.values)..remove(null);

    for (var removed in oldUpstream.difference(newUpstreamSet)) {
      var wasRemoved = removed._downstream.remove(this);
      assert(wasRemoved);
    }

    for (var added in newUpstreamSet.difference(oldUpstream)) {
      var wasAdded = added._downstream.add(this);
      assert(wasAdded);
    }

    _upstream = newUpstream;
  }

  /// Removes [this] as an upstream and downstream node from all the nodes that
  /// import it and that it imports.
  void _remove() {
    for (var node in upstream.values) {
      if (node == null) continue;
      var wasRemoved = node._downstream.remove(this);
      assert(wasRemoved);
    }

    for (var node in downstream) {
      for (var url in node._upstream.keys.toList()) {
        if (node._upstream[url] == this) {
          node._upstream[url] = null;
          break;
        }
      }
    }
  }
}
