// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_import_cache.dart.
// See tool/synchronize.dart for details.
//
// Checksum: 57c42546fb8e0b68e29ea841ba106ee99127bede

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'ast/sass.dart';
import 'importer.dart';
import 'logger.dart';
import 'sync_package_resolver.dart';
import 'utils.dart'; // ignore: unused_import

/// An in-memory cache of parsed stylesheets that have been imported by Sass.
class ImportCache {
  /// A cache that contains no importers.
  static const none = const ImportCache._none();

  /// The importers to use when loading new Sass files.
  final List<Importer> _importers;

  /// The logger to use to emit warnings when parsing stylesheets.
  final Logger _logger;

  /// The canonicalized URLs for each non-canonical URL.
  ///
  /// This map's values are the same as the return value of [canonicalize].
  ///
  /// This cache isn't used for relative imports, because they're
  /// context-dependent.
  final Map<Uri, Tuple3<Importer, Uri, Uri>> _canonicalizeCache;

  /// The parsed stylesheets for each canonicalized import URL.
  final Map<Uri, Stylesheet> _importCache;

  /// Creates an import cache that resolves imports using [importers].
  ///
  /// Imports are resolved by trying, in order:
  ///
  /// * Each importer in [importers].
  ///
  /// * Each load path in [loadPaths]. Note that this is a shorthand for adding
  ///   [FilesystemImporter]s to [importers].
  ///
  /// * `package:` resolution using [packageResolver], which is a
  ///   [`SyncPackageResolver`][] from the `package_resolver` package. Note that
  ///   this is a shorthand for adding a [PackageImporter] to [importers].
  ///
  /// [`SyncPackageResolver`]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
  ImportCache(Iterable<Importer> importers,
      {Iterable<String> loadPaths,
      SyncPackageResolver packageResolver,
      Logger logger})
      : _importers = _toImporters(importers, loadPaths, packageResolver),
        _logger = logger ?? const Logger.stderr(),
        _canonicalizeCache = {},
        _importCache = {};

  /// Converts the user's [importers], [loadPaths], and [packageResolver]
  /// options into a single list of importers.
  static List<Importer> _toImporters(Iterable<Importer> importers,
      Iterable<String> loadPaths, SyncPackageResolver packageResolver) {
    var list = importers?.toList() ?? [];
    if (loadPaths != null) {
      list.addAll(loadPaths.map((path) => new FilesystemImporter(path)));
    }
    if (packageResolver != null) {
      list.add(new PackageImporter(packageResolver));
    }
    return list;
  }

  /// Creates a cache that contains no importers.
  const ImportCache._none()
      : _importers = const [],
        _logger = const Logger.stderr(),
        _canonicalizeCache = const {},
        _importCache = const {};

  /// Canonicalizes [url] according to one of this cache's importers.
  ///
  /// Returns the importer that was used to canonicalize [url], the canonical
  /// URL, and the URL that was passed to the importer (which may be resolved
  /// relative to [baseUrl] if it's passed).
  ///
  /// If [baseImporter] is non-`null`, this first tries to use [baseImporter] to
  /// canonicalize [url] (resolved relative to [baseUrl] if it's passed).
  ///
  /// If any importers understand [url], returns that importer as well as the
  /// canonicalized URL. Otherwise, returns `null`.
  Tuple3<Importer, Uri, Uri> canonicalize(Uri url,
      [Importer baseImporter, Uri baseUrl]) {
    if (baseImporter != null) {
      var resolvedUrl = baseUrl != null ? baseUrl.resolveUri(url) : url;
      var canonicalUrl = _canonicalize(baseImporter, resolvedUrl);
      if (canonicalUrl != null) {
        return new Tuple3(baseImporter, canonicalUrl, resolvedUrl);
      }
    }

    return _canonicalizeCache.putIfAbsent(url, () {
      for (var importer in _importers) {
        var canonicalUrl = _canonicalize(importer, url);
        if (canonicalUrl != null) {
          return new Tuple3(importer, canonicalUrl, url);
        }
      }

      return null;
    });
  }

  /// Calls [importer.canonicalize] and prints a deprecation warning if it
  /// returns a relative URL.
  Uri _canonicalize(Importer importer, Uri url) {
    var result = importer.canonicalize(url);
    if (result?.scheme == '') {
      _logger.warn("""
Importer $importer canonicalized $url to $result.
Relative canonical URLs are deprecated and will eventually be disallowed.
""", deprecation: true);
    }
    return result;
  }

  /// Tries to import [url] using one of this cache's importers.
  ///
  /// If [baseImporter] is non-`null`, this first tries to use [baseImporter] to
  /// import [url] (resolved relative to [baseUrl] if it's passed).
  ///
  /// If any importers can import [url], returns that importer as well as the
  /// parsed stylesheet. Otherwise, returns `null`.
  ///
  /// Caches the result of the import and uses cached results if possible.
  Tuple2<Importer, Stylesheet> import(Uri url,
      [Importer baseImporter, Uri baseUrl]) {
    var tuple = canonicalize(url, baseImporter, baseUrl);
    if (tuple == null) return null;
    var stylesheet = importCanonical(tuple.item1, tuple.item2, tuple.item3);
    return new Tuple2(tuple.item1, stylesheet);
  }

  /// Tries to load the canonicalized [canonicalUrl] using [importer].
  ///
  /// If [importer] can import [canonicalUrl], returns the imported [Stylesheet].
  /// Otherwise returns `null`.
  ///
  /// If passed, the [originalUrl] represents the URL that was canonicalized
  /// into [canonicalUrl]. It's used as the URL for the parsed stylesheet, which
  /// is in turn used in error reporting.
  ///
  /// Caches the result of the import and uses cached results if possible.
  Stylesheet importCanonical(Importer importer, Uri canonicalUrl,
      [Uri originalUrl]) {
    return _importCache.putIfAbsent(canonicalUrl, () {
      var result = importer.load(canonicalUrl);
      if (result == null) return null;
      return new Stylesheet.parse(result.contents, result.syntax,
          // For backwards-compatibility, relative canonical URLs are resolved
          // relative to [originalUrl].
          url: originalUrl == null
              ? canonicalUrl
              : originalUrl.resolveUri(canonicalUrl),
          logger: _logger);
    });
  }

  /// Return a human-friendly URL for [canonicalUrl] to use in a stack trace.
  ///
  /// Throws a [StateError] if the stylesheet for [canonicalUrl] hasn't been
  /// loaded by this cache.
  Uri humanize(Uri canonicalUrl) {
    // Display the URL with the shortest path length.
    var url = minBy(
        _canonicalizeCache.values
            .where((tuple) => tuple?.item2 == canonicalUrl)
            .map((tuple) => tuple.item3),
        (url) => url.path.length);
    if (url == null) return canonicalUrl;

    // Use the canonicalized basename so that we display e.g.
    // package:example/_example.scss rather than package:example/example in
    // stack traces.
    return url.resolve(p.url.basename(canonicalUrl.path));
  }

  /// Clears the cached canonical version of the given [url].
  ///
  /// Has no effect if the canonical version of [url] has not been cached.
  void clearCanonicalize(Uri url) {
    _canonicalizeCache.remove(url);
  }

  /// Clears the cached parse tree for the stylesheet with the given
  /// [canonicalUrl].
  ///
  /// Has no effect if the imported file at [canonicalUrl] has not been cached.
  void clearImport(Uri canonicalUrl) {
    _importCache.remove(canonicalUrl);
  }
}
