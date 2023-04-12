// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_import_cache.dart.
// See tool/grind/synchronize.dart for details.
//
// Checksum: d844d818b4acd784d562928949b138f5698fc248
//
// ignore_for_file: unused_import

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'ast/sass.dart';
import 'deprecation.dart';
import 'importer.dart';
import 'importer/utils.dart';
import 'io.dart';
import 'logger.dart';
import 'utils.dart';

/// An in-memory cache of parsed stylesheets that have been imported by Sass.
///
/// {@category Dependencies}
@sealed
class ImportCache {
  /// The importers to use when loading new Sass files.
  final List<Importer> _importers;

  /// The logger to use to emit warnings when parsing stylesheets.
  final Logger _logger;

  /// The canonicalized URLs for each non-canonical URL.
  ///
  /// The second item in each key's tuple is true when this canonicalization is
  /// for an `@import` rule. Otherwise, it's for a `@use` or `@forward` rule.
  ///
  /// This map's values are the same as the return value of [canonicalize].
  ///
  /// This cache isn't used for relative imports, because they depend on the
  /// specific base importer. That's stored separately in
  /// [_relativeCanonicalizeCache].
  final _canonicalizeCache = <Tuple2<Uri, bool>, Tuple3<Importer, Uri, Uri>?>{};

  /// The canonicalized URLs for each non-canonical URL that's resolved using a
  /// relative importer.
  ///
  /// The map's keys have four parts:
  ///
  /// 1. The URL passed to [canonicalize] (the same as in [_canonicalizeCache]).
  /// 2. Whether the canonicalization is for an `@import` rule.
  /// 3. The `baseImporter` passed to [canonicalize].
  /// 4. The `baseUrl` passed to [canonicalize].
  ///
  /// The map's values are the same as the return value of [canonicalize].
  final _relativeCanonicalizeCache =
      <Tuple4<Uri, bool, Importer, Uri?>, Tuple3<Importer, Uri, Uri>?>{};

  /// The parsed stylesheets for each canonicalized import URL.
  final _importCache = <Uri, Stylesheet?>{};

  /// The import results for each canonicalized import URL.
  final _resultsCache = <Uri, ImporterResult>{};

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
  /// * `package:` resolution using [packageConfig], which is a
  ///   [`PackageConfig`][] from the `package_config` package. Note that
  ///   this is a shorthand for adding a [PackageImporter] to [importers].
  ///
  /// [`PackageConfig`]: https://pub.dev/documentation/package_config/latest/package_config.package_config/PackageConfig-class.html
  ImportCache(
      {Iterable<Importer>? importers,
      Iterable<String>? loadPaths,
      PackageConfig? packageConfig,
      Logger? logger})
      : _importers = _toImporters(importers, loadPaths, packageConfig),
        _logger = logger ?? const Logger.stderr();

  /// Creates an import cache without any globally-available importers.
  ImportCache.none({Logger? logger})
      : _importers = const [],
        _logger = logger ?? const Logger.stderr();

  /// Converts the user's [importers], [loadPaths], and [packageConfig]
  /// options into a single list of importers.
  static List<Importer> _toImporters(Iterable<Importer>? importers,
      Iterable<String>? loadPaths, PackageConfig? packageConfig) {
    var sassPath = getEnvironmentVariable('SASS_PATH');
    if (isBrowser) {
      return [...?importers];
    }
    return [
      ...?importers,
      if (loadPaths != null)
        for (var path in loadPaths) FilesystemImporter(path),
      if (sassPath != null)
        for (var path in sassPath.split(isWindows ? ';' : ':'))
          FilesystemImporter(path),
      if (packageConfig != null) PackageImporter(packageConfig)
    ];
  }

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
  /// canonicalized URL and the original URL (resolved relative to [baseUrl] if
  /// applicable). Otherwise, returns `null`.
  Tuple3<Importer, Uri, Uri>? canonicalize(Uri url,
      {Importer? baseImporter, Uri? baseUrl, bool forImport = false}) {
    if (baseImporter != null) {
      var relativeResult = _relativeCanonicalizeCache
          .putIfAbsent(Tuple4(url, forImport, baseImporter, baseUrl), () {
        var resolvedUrl = baseUrl?.resolveUri(url) ?? url;
        var canonicalUrl = _canonicalize(baseImporter, resolvedUrl, forImport);
        if (canonicalUrl == null) return null;
        return Tuple3(baseImporter, canonicalUrl, resolvedUrl);
      });
      if (relativeResult != null) return relativeResult;
    }

    return _canonicalizeCache.putIfAbsent(Tuple2(url, forImport), () {
      for (var importer in _importers) {
        var canonicalUrl = _canonicalize(importer, url, forImport);
        if (canonicalUrl != null) {
          return Tuple3(importer, canonicalUrl, url);
        }
      }

      return null;
    });
  }

  /// Calls [importer.canonicalize] and prints a deprecation warning if it
  /// returns a relative URL.
  Uri? _canonicalize(Importer importer, Uri url, bool forImport) {
    var result = (forImport
        ? inImportRule(() => importer.canonicalize(url))
        : importer.canonicalize(url));
    if (result?.scheme == '') {
      _logger.warnForDeprecation(Deprecation.relativeCanonical, """
Importer $importer canonicalized $url to $result.
Relative canonical URLs are deprecated and will eventually be disallowed.
""");
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
  Tuple2<Importer, Stylesheet>? import(Uri url,
      {Importer? baseImporter, Uri? baseUrl, bool forImport = false}) {
    var tuple = canonicalize(url,
        baseImporter: baseImporter, baseUrl: baseUrl, forImport: forImport);
    if (tuple == null) return null;
    var stylesheet =
        importCanonical(tuple.item1, tuple.item2, originalUrl: tuple.item3);
    if (stylesheet == null) return null;
    return Tuple2(tuple.item1, stylesheet);
  }

  /// Tries to load the canonicalized [canonicalUrl] using [importer].
  ///
  /// If [importer] can import [canonicalUrl], returns the imported [Stylesheet].
  /// Otherwise returns `null`.
  ///
  /// If passed, the [originalUrl] represents the URL that was canonicalized
  /// into [canonicalUrl]. It's used to resolve a relative canonical URL, which
  /// importers may return for legacy reasons.
  ///
  /// If [quiet] is `true`, this will disable logging warnings when parsing the
  /// newly imported stylesheet.
  ///
  /// Caches the result of the import and uses cached results if possible.
  Stylesheet? importCanonical(Importer importer, Uri canonicalUrl,
      {Uri? originalUrl, bool quiet = false}) {
    return _importCache.putIfAbsent(canonicalUrl, () {
      var result = importer.load(canonicalUrl);
      if (result == null) return null;

      _resultsCache[canonicalUrl] = result;
      return Stylesheet.parse(result.contents, result.syntax,
          // For backwards-compatibility, relative canonical URLs are resolved
          // relative to [originalUrl].
          url: originalUrl == null
              ? canonicalUrl
              : originalUrl.resolveUri(canonicalUrl),
          logger: quiet ? Logger.quiet : _logger);
    });
  }

  /// Return a human-friendly URL for [canonicalUrl] to use in a stack trace.
  ///
  /// Returns [canonicalUrl] as-is if it hasn't been loaded by this cache.
  Uri humanize(Uri canonicalUrl) {
    // Display the URL with the shortest path length.
    var url = minBy<Uri, int>(
        _canonicalizeCache.values
            .whereNotNull()
            .where((tuple) => tuple.item2 == canonicalUrl)
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
  ///
  /// @nodoc
  @internal
  void clearCanonicalize(Uri url) {
    _canonicalizeCache.remove(Tuple2(url, false));
    _canonicalizeCache.remove(Tuple2(url, true));

    var relativeKeysToClear = [
      for (var key in _relativeCanonicalizeCache.keys)
        if (key.item1 == url) key
    ];
    for (var key in relativeKeysToClear) {
      _relativeCanonicalizeCache.remove(key);
    }
  }

  /// Clears the cached parse tree for the stylesheet with the given
  /// [canonicalUrl].
  ///
  /// Has no effect if the imported file at [canonicalUrl] has not been cached.
  ///
  /// @nodoc
  @internal
  void clearImport(Uri canonicalUrl) {
    _resultsCache.remove(canonicalUrl);
    _importCache.remove(canonicalUrl);
  }
}
