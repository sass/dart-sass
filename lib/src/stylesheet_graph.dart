// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'ast/sass.dart';
import 'import_cache.dart';
import 'importer.dart';
import 'util/nullable.dart';
import 'visitor/find_dependencies.dart';

/// A graph of the import relationships between stylesheets, available via
/// [nodes].
class StylesheetGraph {
  /// A map from canonical URLs to the stylesheet nodes for those URLs.
  Map<Uri, StylesheetNode> get nodes => UnmodifiableMapView(_nodes);
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
      [Importer? baseImporter, Uri? baseUrl]) {
    DateTime transitiveModificationTime(StylesheetNode node) {
      return _transitiveModificationTimes.putIfAbsent(node.canonicalUrl, () {
        var latest = node.importer.modificationTime(node.canonicalUrl);
        for (var upstream
            in node.upstream.values.followedBy(node.upstreamImports.values)) {
          // If an import is missing, always recompile so we show the user the
          // error.
          var upstreamTime = upstream == null
              ? DateTime.now()
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
  StylesheetNode? _add(Uri url, [Importer? baseImporter, Uri? baseUrl]) {
    var tuple = _ignoreErrors(() => importCache.canonicalize(url,
        baseImporter: baseImporter, baseUrl: baseUrl));
    if (tuple == null) return null;

    addCanonical(tuple.item1, tuple.item2, tuple.item3);
    return nodes[tuple.item2];
  }

  /// Adds the stylesheet at the canonicalized [canonicalUrl] and all the
  /// stylesheets it imports to this graph and returns its node.
  ///
  /// If passed, the [originalUrl] represents the URL that was canonicalized
  /// into [canonicalUrl]. It's used to resolve a relative canonical URL, which
  /// importers may return for legacy reasons.
  ///
  /// Returns the set of nodes that need to be recompiled because their imports
  /// changed as a result of this stylesheet being added. This does not include
  /// the new stylesheet, which can be accessed via `nodes[canonicalUrl]`.
  ///
  /// If [recanonicalize] is `false`, this instead avoids checking downstream
  /// nodes' imports and always returns an empty set. It should only be set to
  /// `false` when initially adding stylesheets, not when handling future
  /// updates.
  Set<StylesheetNode> addCanonical(
      Importer importer, Uri canonicalUrl, Uri originalUrl,
      {bool recanonicalize = true}) {
    var node = _nodes[canonicalUrl];
    if (node != null) return const {};

    var stylesheet = _ignoreErrors(
        () => importCache.importCanonical(importer, canonicalUrl, originalUrl));
    if (stylesheet == null) return const {};

    node = StylesheetNode._(stylesheet, importer, canonicalUrl,
        _upstreamNodes(stylesheet, importer, canonicalUrl));
    _nodes[canonicalUrl] = node;

    return recanonicalize
        ? _recanonicalizeImports(importer, canonicalUrl)
        : const {};
  }

  /// Returns two maps from non-canonicalized imported URLs in [stylesheet] to
  /// nodes, which appears within [baseUrl] imported by [baseImporter].
  ///
  /// The first map contains stylesheets depended on via `@use` and `@forward`
  /// while the second map contains those depended on via `@import`.
  Tuple2<Map<Uri, StylesheetNode?>, Map<Uri, StylesheetNode?>> _upstreamNodes(
      Stylesheet stylesheet, Importer baseImporter, Uri baseUrl) {
    var active = {baseUrl};
    var tuple = findDependencies(stylesheet);
    return Tuple2({
      for (var url in tuple.item1)
        url: _nodeFor(url, baseImporter, baseUrl, active)
    }, {
      for (var url in tuple.item2)
        url: _nodeFor(url, baseImporter, baseUrl, active, forImport: true)
    });
  }

  /// Re-parses the stylesheet at [canonicalUrl] and updates the dependency graph
  /// accordingly.
  ///
  /// Throws a [StateError] if [canonicalUrl] isn't already in the dependency graph.
  ///
  /// Returns `false` if the stylesheet's importer can no longer import it. The
  /// caller is responsible for then calling [remove].
  bool reload(Uri canonicalUrl) {
    var node = _nodes[canonicalUrl];
    if (node == null) {
      throw StateError("$canonicalUrl is not in the dependency graph.");
    }

    // Rather than spending time computing exactly which modification times
    // should be updated, just clear the cache and let it be computed again
    // later.
    _transitiveModificationTimes.clear();

    importCache.clearImport(canonicalUrl);
    var stylesheet = _ignoreErrors(
        () => importCache.importCanonical(node.importer, canonicalUrl));
    if (stylesheet == null) return false;
    node._stylesheet = stylesheet;

    var upstream = _upstreamNodes(stylesheet, node.importer, canonicalUrl);
    node._replaceUpstream(upstream.item1, upstream.item2);
    return true;
  }

  /// Removes the stylesheet at [canonicalUrl] (loaded by [importer]) from the
  /// stylesheet graph.
  ///
  /// Note that [canonicalUrl] doesn't necessarily need to be in the stylesheet
  /// graph itself. It may still be relevant to know that it's been removed,
  /// because it could resolve import conflicts in stylesheets that *are* in the
  /// graph.
  ///
  /// Returns the set of nodes that need to be recompiled because this node was
  /// removed.
  Set<StylesheetNode> remove(Importer importer, Uri canonicalUrl) {
    var node = _nodes.remove(canonicalUrl);
    if (node != null) {
      // Rather than spending time computing exactly which modification times
      // should be updated, just clear the cache and let it be computed again
      // later.
      _transitiveModificationTimes.clear();
      importCache.clearImport(canonicalUrl);
      node._remove();
    }

    // We can't just recanonicalize [node.downstream] here, because it's
    // possible that removing [node] fixed an import conflict, in which case the
    // stylesheet with the import conflict should now be recompiled.
    var toRecompile = _recanonicalizeImports(importer, canonicalUrl);
    if (node != null) toRecompile.addAll(node._downstream);
    return toRecompile;
  }

  /// Re-runs canonicalization for all URLs in the graph that could possibly
  /// refer to [canonicalUrl] which was loaded via [Importer].
  ///
  /// Returns all nodes whose imports were changed.
  Set<StylesheetNode> _recanonicalizeImports(
      Importer importer, Uri canonicalUrl) {
    var changed = <StylesheetNode>{};
    for (var node in nodes.values) {
      var newUpstream = _recanonicalizeImportsForNode(
          node, importer, canonicalUrl,
          forImport: false);
      var newUpstreamImports = _recanonicalizeImportsForNode(
          node, importer, canonicalUrl,
          forImport: true);

      if (newUpstream.isNotEmpty || newUpstreamImports.isNotEmpty) {
        changed.add(node);
        node._replaceUpstream(mergeMaps(node.upstream, newUpstream),
            mergeMaps(node.upstreamImports, newUpstreamImports));
      }
    }

    // Rather than spending time computing exactly which modification times
    // should be updated, just clear the cache and let it be computed again
    // later.
    if (changed.isNotEmpty) _transitiveModificationTimes.clear();

    return changed;
  }

  /// Re-runs canonicaliation for all URLs in [node]'s upstream nodes that could
  /// possibly refer to [canonicalUrl] (which was loaded via [importer]) and
  /// returns a map from differently-canonicalized URLs to their new nodes.
  ///
  /// If [forImport] is `true`, this re-runs canonicalization for
  /// [node.upstreamImports]. Otherwise, it re-runs canonicalization for
  /// [node.upstream].
  Map<Uri, StylesheetNode?> _recanonicalizeImportsForNode(
      StylesheetNode node, Importer importer, Uri canonicalUrl,
      {required bool forImport}) {
    var map = forImport ? node.upstreamImports : node.upstream;
    var newMap = <Uri, StylesheetNode?>{};
    map.forEach((url, upstream) {
      if (!importer.couldCanonicalize(url, canonicalUrl)) return;
      importCache.clearCanonicalize(url);

      // If the import produces a different canonicalized URL than it did
      // before, it changed and the stylesheet needs to be recompiled.
      Tuple3<AsyncImporter, Uri, Uri>? result;
      try {
        result = importCache.canonicalize(url,
            baseImporter: node.importer,
            baseUrl: node.canonicalUrl,
            forImport: forImport);
      } catch (_) {
        // If the call to canonicalize failed, we ignore the error so that
        // it can be surfaced more gracefully when [node]'s stylesheet is
        // recompiled.
      }

      var newCanonicalUrl = result?.item2;
      if (newCanonicalUrl == upstream?.canonicalUrl) return;

      newMap[url] = result == null ? null : nodes[result.item2];
    });
    return newMap;
  }

  /// Returns the [StylesheetNode] for the stylesheet at the given [url], which
  /// appears within [baseUrl] imported by [baseImporter].
  ///
  /// The [active] set should contain the canonical URLs that are currently
  /// being imported. It's used to detect circular imports.
  StylesheetNode? _nodeFor(
      Uri url, Importer baseImporter, Uri baseUrl, Set<Uri> active,
      {bool forImport = false}) {
    var tuple = _ignoreErrors(() => importCache.canonicalize(url,
        baseImporter: baseImporter, baseUrl: baseUrl, forImport: forImport));

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
    var node = StylesheetNode._(stylesheet, importer, canonicalUrl,
        _upstreamNodes(stylesheet, importer, canonicalUrl));
    active.remove(canonicalUrl);
    _nodes[canonicalUrl] = node;
    return node;
  }

  /// Runs [callback] and returns its result.
  ///
  /// If [callback] throws any errors, ignores them and returns `null`. This is
  /// used to wrap calls to the import cache, since importer errors should be
  /// surfaced by the compilation process rather than the graph.
  T? _ignoreErrors<T>(T callback()) {
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

  /// A map from non-canonicalized `@use` and `@forward` URLs in [stylesheet] to
  /// the stylesheets those rules refer to.
  ///
  /// This may have `null` values, which indicate failed loads.
  Map<Uri, StylesheetNode?> get upstream => UnmodifiableMapView(_upstream);
  Map<Uri, StylesheetNode?> _upstream;

  /// A map from non-canonicalized `@import` URLs in [stylesheet] to the
  /// stylesheets those imports refer to.
  ///
  /// This may have `null` values, which indicate failed imports.
  Map<Uri, StylesheetNode?> get upstreamImports =>
      UnmodifiableMapView(_upstreamImports);
  Map<Uri, StylesheetNode?> _upstreamImports;

  /// The stylesheets that import [stylesheet].
  Set<StylesheetNode> get downstream => UnmodifiableSetView(_downstream);
  final _downstream = <StylesheetNode>{};

  StylesheetNode._(this._stylesheet, this.importer, this.canonicalUrl,
      Tuple2<Map<Uri, StylesheetNode?>, Map<Uri, StylesheetNode?>> allUpstream)
      : _upstream = allUpstream.item1,
        _upstreamImports = allUpstream.item2 {
    for (var node in upstream.values.followedBy(upstreamImports.values)) {
      if (node != null) node._downstream.add(this);
    }
  }

  /// Updates [upstream] and [upstreamImports] from [newUpstream] and
  /// [newUpstreamImports] and adjusts upstream nodes' [downstream] fields
  /// accordingly.
  void _replaceUpstream(Map<Uri, StylesheetNode?> newUpstream,
      Map<Uri, StylesheetNode?> newUpstreamImports) {
    var oldUpstream =
        {...upstream.values, ...upstreamImports.values}.removeNull();
    var newUpstreamSet =
        {...newUpstream.values, ...newUpstreamImports.values}.removeNull();

    for (var removed in oldUpstream.difference(newUpstreamSet)) {
      var wasRemoved = removed._downstream.remove(this);
      assert(wasRemoved);
    }

    for (var added in newUpstreamSet.difference(oldUpstream)) {
      var wasAdded = added._downstream.add(this);
      assert(wasAdded);
    }

    _upstream = newUpstream;
    _upstreamImports = newUpstreamImports;
  }

  /// Removes [this] as an upstream and downstream node from all the nodes that
  /// import it and that it imports.
  void _remove() {
    for (var node in {...upstream.values, ...upstreamImports.values}) {
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
      for (var url in node._upstreamImports.keys.toList()) {
        if (node._upstreamImports[url] == this) {
          node._upstreamImports[url] = null;
          break;
        }
      }
    }
  }

  String toString() =>
      stylesheet.span?.sourceUrl.andThen(p.prettyUri) ?? '<unknown>';
}
