// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'ast/sass.dart';
import 'importer.dart';
import 'importer/result.dart';
import 'importer/utils.dart';
import 'io.dart';
import 'logger.dart';
import 'sync_package_resolver.dart';
import 'utils.dart'; // ignore: unused_import

/// An in-memory cache of parsed stylesheets that have been imported by Sass.
class AsyncImportCache {
  /// The importers to use when loading new Sass files.
  final List<AsyncImporter> _importers;

  /// The logger to use to emit warnings when parsing stylesheets.
  final Logger _logger;

  /// The canonicalized URLs for each non-canonical URL.
  ///
  /// The second item in each key's tuple is true when this canonicalization is
  /// for an `@import` rule. Otherwise, it's for a `@use` or `@forward` rule.
  ///
  /// This map's values are the same as the return value of [canonicalize].
  ///
  /// This cache isn't used for relative imports, because they're
  /// context-dependent.
  final Map<Tuple2<Uri, bool>, Tuple3<AsyncImporter, Uri, Uri>>
      _canonicalizeCache;

  /// The parsed stylesheets for each canonicalized import URL.
  final Map<Uri, Stylesheet> _importCache;

  /// The import results for each canonicalized import URL.
  final Map<Uri, ImporterResult> _resultsCache;

  /// Creates an import cache that resolves imports using [importers].
  ///
  /// Imports are resolved by trying, in order:
  ///
  /// * Each importer in [importers].
  ///
  /// * Each load path in [loadPaths]. Note that this is a shorthand for adding
  ///   [FilesystemImporter]s to [importers].
  ///
  /// * Each load path specified in the `SASS_PATH` environment variable, which
  ///   should be semicolon-separated on Windows and colon-separated elsewhere.
  ///
  /// * `package:` resolution using [packageResolver], which is a
  ///   [`SyncPackageResolver`][] from the `package_resolver` package. Note that
  ///   this is a shorthand for adding a [PackageImporter] to [importers].
  ///
  /// [`SyncPackageResolver`]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
  AsyncImportCache(Iterable<AsyncImporter> importers,
      {Iterable<String> loadPaths,
      SyncPackageResolver packageResolver,
      Logger logger})
      : _importers = _toImporters(importers, loadPaths, packageResolver),
        _logger = logger ?? const Logger.stderr(),
        _canonicalizeCache = {},
        _importCache = {},
        _resultsCache = {};

  /// Creates an import cache without any globally-available importers.
  AsyncImportCache.none({Logger logger})
      : _importers = const [],
        _logger = logger ?? const Logger.stderr(),
        _canonicalizeCache = {},
        _importCache = {},
        _resultsCache = {};

  /// Converts the user's [importers], [loadPaths], and [packageResolver]
  /// options into a single list of importers.
  static List<AsyncImporter> _toImporters(Iterable<AsyncImporter> importers,
      Iterable<String> loadPaths, SyncPackageResolver packageResolver) {
    var sassPath = getEnvironmentVariable('SASS_PATH');
    return [
      ...?importers,
      if (loadPaths != null)
        for (var path in loadPaths) FilesystemImporter(path),
      if (sassPath != null)
        for (var path in sassPath.split(isWindows ? ';' : ':'))
          FilesystemImporter(path),
      if (packageResolver != null) PackageImporter(packageResolver)
    ];
  }

  /// Creates a cache that contains no importers.
  const AsyncImportCache._none()
      : _importers = const [],
        _logger = const Logger.stderr(),
        _canonicalizeCache = const {},
        _importCache = const {},
        _resultsCache = const {};

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
  Future<Tuple3<AsyncImporter, Uri, Uri>> canonicalize(Uri url,
      {AsyncImporter baseImporter, Uri baseUrl, bool forImport = false}) async {
    if (baseImporter != null) {
      var resolvedUrl = baseUrl != null ? baseUrl.resolveUri(url) : url;
      var canonicalUrl =
          await _canonicalize(baseImporter, resolvedUrl, forImport);
      if (canonicalUrl != null) {
        return Tuple3(baseImporter, canonicalUrl, resolvedUrl);
      }
    }

    return await putIfAbsentAsync(_canonicalizeCache, Tuple2(url, forImport),
        () async {
      for (var importer in _importers) {
        var canonicalUrl = await _canonicalize(importer, url, forImport);
        if (canonicalUrl != null) {
          return Tuple3(importer, canonicalUrl, url);
        }
      }

      return null;
    });
  }

  /// Calls [importer.canonicalize] and prints a deprecation warning if it
  /// returns a relative URL.
  Future<Uri> _canonicalize(
      AsyncImporter importer, Uri url, bool forImport) async {
    var result = await (forImport
        ? inImportRule(() => importer.canonicalize(url))
        : importer.canonicalize(url));
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
  Future<Tuple2<AsyncImporter, Stylesheet>> import(Uri url,
      {AsyncImporter baseImporter, Uri baseUrl, bool forImport = false}) async {
    var tuple = await canonicalize(url,
        baseImporter: baseImporter, baseUrl: baseUrl, forImport: forImport);
    if (tuple == null) return null;
    var stylesheet =
        await importCanonical(tuple.item1, tuple.item2, tuple.item3);
    return Tuple2(tuple.item1, stylesheet);
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
  Future<Stylesheet> importCanonical(AsyncImporter importer, Uri canonicalUrl,
      [Uri originalUrl]) async {
    return await putIfAbsentAsync(_importCache, canonicalUrl, () async {
      var result = await importer.load(canonicalUrl);
      if (result == null) return null;

      _resultsCache[canonicalUrl] = result;
      return Stylesheet.parse(result.contents, result.syntax,
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
  /// Returns [canonicalUrl] as-is if it hasn't been loaded by this cache.
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

  /// Returns the URL to use in the source map to refer to [canonicalUrl].
  ///
  /// Returns [canonicalUrl] as-is if it hasn't been loaded by this cache.
  Uri sourceMapUrl(Uri canonicalUrl) =>
      _resultsCache[canonicalUrl]?.sourceMapUrl ?? canonicalUrl;

  /// Clears the cached canonical version of the given [url].
  ///
  /// Has no effect if the canonical version of [url] has not been cached.
  void clearCanonicalize(Uri url) {
    _canonicalizeCache.remove(Tuple2(url, false));
    _canonicalizeCache.remove(Tuple2(url, true));
  }

  /// Clears the cached parse tree for the stylesheet with the given
  /// [canonicalUrl].
  ///
  /// Has no effect if the imported file at [canonicalUrl] has not been cached.
  void clearImport(Uri canonicalUrl) {
    _resultsCache.remove(canonicalUrl);
    _importCache.remove(canonicalUrl);
  }
}
