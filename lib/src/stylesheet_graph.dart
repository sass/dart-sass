// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'import_cache.dart';
import 'importer.dart';
import 'visitor/find_imports.dart';

/// A graph of the import relationships between stylesheets.
class StylesheetGraph {
  /// A map from canonical URLs to the stylesheet nodes for those URLs.
  final _nodes = <Uri, _StylesheetNode>{};

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
    DateTime transitiveModificationTime(_StylesheetNode node) {
      return _transitiveModificationTimes.putIfAbsent(node.canonicalUrl, () {
        var latest = node.importer.modificationTime(node.canonicalUrl);
        for (var upstream in node.upstream) {
          var upstreamTime = transitiveModificationTime(upstream);
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
  _StylesheetNode _add(Uri url, [Importer baseImporter, Uri baseUrl]) {
    var tuple = importCache.canonicalize(url, baseImporter, baseUrl);
    if (tuple == null) return null;
    var importer = tuple.item1;
    var canonicalUrl = tuple.item2;

    return _nodes.putIfAbsent(canonicalUrl, () {
      var stylesheet = importCache.importCanonical(importer, canonicalUrl);
      if (stylesheet == null) return null;

      var active = new Set<Uri>.from([canonicalUrl]);
      return new _StylesheetNode(
          stylesheet,
          importer,
          canonicalUrl,
          findImports(stylesheet)
              .map((import) => _nodeFor(
                  Uri.parse(import.url), importer, canonicalUrl, active))
              .where((node) => node != null));
    });
  }

  /// Returns the [StylesheetNode] for the stylesheet at the given [url], which
  /// appears within [baseUrl] imported by [baseImporter].
  ///
  /// The [active] set should contain the canonical URLs that are currently
  /// being imported. It's used to detect circular imports.
  _StylesheetNode _nodeFor(
      Uri url, Importer baseImporter, Uri baseUrl, Set<Uri> active) {
    var tuple = importCache.canonicalize(url, baseImporter, baseUrl);

    // If an import fails, let the evaluator surface that error rather than
    // surfacing it here.
    if (tuple == null) return null;
    var importer = tuple.item1;
    var canonicalUrl = tuple.item2;

    // Don't use [putIfAbsent] here because we want to avoid adding an entry if
    // the import fails.
    if (_nodes.containsKey(canonicalUrl)) return _nodes[canonicalUrl];

    /// If we detect a circular import, act as though it doesn't exist. A better
    /// error will be produced during compilation.
    if (active.contains(canonicalUrl)) return null;

    var stylesheet = importCache.importCanonical(importer, canonicalUrl);
    if (stylesheet == null) return null;

    active.add(canonicalUrl);
    var node = new _StylesheetNode(
        stylesheet,
        importer,
        canonicalUrl,
        findImports(stylesheet)
            .map((import) =>
                _nodeFor(Uri.parse(import.url), importer, canonicalUrl, active))
            .where((node) => node != null));
    active.remove(canonicalUrl);
    _nodes[canonicalUrl] = node;
    return node;
  }
}

/// A node in a [StylesheetGraph] that tracks a single stylesheet and all the
/// upstream stylesheets it imports and the downstream stylesheets that import
/// it.
///
/// A [StylesheetNode] is immutable except for its downstream nodes. When the
/// stylesheet itself changes, a new node should be generated.
class _StylesheetNode {
  /// The parsed stylesheet.
  final Stylesheet stylesheet;

  /// The importer that was used to load this stylesheet.
  final Importer importer;

  /// The canonical URL of [stylesheet].
  final Uri canonicalUrl;

  /// The stylesheets that [stylesheet] imports.
  final List<_StylesheetNode> upstream;

  /// The stylesheets that import [stylesheet].
  ///
  /// This is automatically populated when new [_StylesheetNode]s are created
  /// that list this as an upstream node.
  final downstream = new Set<_StylesheetNode>();

  _StylesheetNode(this.stylesheet, this.importer, this.canonicalUrl,
      Iterable<_StylesheetNode> upstream)
      : upstream = new List.unmodifiable(upstream) {
    for (var node in upstream) {
      node.downstream.add(this);
    }
  }

  /// Removes [this] as a downstream node from all the upstream nodes that it
  /// imports.
  void remove() {
    for (var node in upstream) {
      var wasRemoved = node.downstream.remove(this);
      assert(wasRemoved);
    }
  }
}
