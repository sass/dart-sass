// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:cli_pkg/js.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';
import 'package:path/path.dart' as p;

import 'ast/sass.dart';
import 'deprecation.dart';
import 'importer.dart';
import 'importer/canonicalize_context.dart';
import 'importer/no_op.dart';
import 'importer/utils.dart';
import 'io.dart';
import 'logger.dart';
import 'util/map.dart';
import 'util/nullable.dart';
import 'utils.dart';

/// A canonicalized URL and the importer that canonicalized it.
///
/// This also includes the URL that was originally passed to the importer, which
/// may be resolved relative to a base URL.
typedef AsyncCanonicalizeResult = (
  AsyncImporter,
  Uri canonicalUrl, {
  Uri originalUrl
});

/// An in-memory cache of parsed stylesheets that have been imported by Sass.
///
/// {@category Dependencies}
final class AsyncImportCache {
  /// The importers to use when loading new Sass files.
  final List<AsyncImporter> _importers;

  /// The logger to use to emit warnings when parsing stylesheets.
  final Logger _logger;

  /// The canonicalized URLs for each non-canonical URL.
  ///
  /// The `forImport` in each key is true when this canonicalization is for an
  /// `@import` rule. Otherwise, it's for a `@use` or `@forward` rule.
  ///
  /// This cache covers loads that go through the entire chain of [_importers],
  /// but it doesn't cover individual loads or loads in which any importer
  /// accesses `containingUrl`. See also [_perImporterCanonicalizeCache].
  final _canonicalizeCache =
      <(Uri, {bool forImport}), AsyncCanonicalizeResult?>{};

  /// Like [_canonicalizeCache] but also includes the specific importer in the
  /// key.
  ///
  /// This is used to cache both relative imports from the base importer and
  /// individual importer results in the case where some other component of the
  /// importer chain isn't cacheable.
  final _perImporterCanonicalizeCache =
      <(AsyncImporter, Uri, {bool forImport}), AsyncCanonicalizeResult?>{};

  /// A map from the keys in [_perImporterCanonicalizeCache] that are generated
  /// for relative URL loads against the base importer to the original relative
  /// URLs what were loaded.
  ///
  /// This is used to invalidate the cache when files are changed.
  final _nonCanonicalRelativeUrls =
      <(AsyncImporter, Uri, {bool forImport}), Uri>{};

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
  AsyncImportCache(
      {Iterable<AsyncImporter>? importers,
      Iterable<String>? loadPaths,
      PackageConfig? packageConfig,
      Logger? logger})
      : _importers = _toImporters(importers, loadPaths, packageConfig),
        _logger = logger ?? const Logger.stderr();

  /// Creates an import cache without any globally-available importers.
  AsyncImportCache.none({Logger? logger})
      : _importers = const [],
        _logger = logger ?? const Logger.stderr();

  /// Creates an import cache without any globally-available importers, and only
  /// the passed in importers.
  AsyncImportCache.only(Iterable<AsyncImporter> importers, {Logger? logger})
      : _importers = List.unmodifiable(importers),
        _logger = logger ?? const Logger.stderr();

  /// Converts the user's [importers], [loadPaths], and [packageConfig]
  /// options into a single list of importers.
  static List<AsyncImporter> _toImporters(Iterable<AsyncImporter>? importers,
      Iterable<String>? loadPaths, PackageConfig? packageConfig) {
    var sassPath = getEnvironmentVariable('SASS_PATH');
    if (isBrowser) return [...?importers];
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
  /// The [baseUrl] should be the canonical URL of the stylesheet that contains
  /// the load, if it exists.
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
  Future<AsyncCanonicalizeResult?> canonicalize(Uri url,
      {AsyncImporter? baseImporter,
      Uri? baseUrl,
      bool forImport = false}) async {
    if (isBrowser &&
        (baseImporter == null || baseImporter is NoOpImporter) &&
        _importers.isEmpty) {
      throw "Custom importers are required to load stylesheets when compiling "
          "in the browser.";
    }

    if (baseImporter != null && url.scheme == '') {
      var resolvedUrl = baseUrl?.resolveUri(url) ?? url;
      var key = (baseImporter, resolvedUrl, forImport: forImport);
      var relativeResult =
          await putIfAbsentAsync(_perImporterCanonicalizeCache, key, () async {
        var (result, cacheable) =
            await _canonicalize(baseImporter, resolvedUrl, baseUrl, forImport);
        assert(
            cacheable,
            "Relative loads should always be cacheable because they never "
            "provide access to the containing URL.");
        if (baseUrl != null) _nonCanonicalRelativeUrls[key] = url;
        return result;
      });
      if (relativeResult != null) return relativeResult;
    }

    var key = (url, forImport: forImport);
    if (_canonicalizeCache.containsKey(key)) return _canonicalizeCache[key];

    // Each individual call to a `canonicalize()` override may not be cacheable
    // (specifically, if it has access to `containingUrl` it's too
    // context-sensitive to usefully cache). We want to cache a given URL across
    // the _entire_ importer chain, so we use [cacheable] to track whether _all_
    // `canonicalize()` calls we've attempted are cacheable. Only if they are, do
    // we store the result in the cache.
    var cacheable = true;
    for (var i = 0; i < _importers.length; i++) {
      var importer = _importers[i];
      var perImporterKey = (importer, url, forImport: forImport);
      switch (_perImporterCanonicalizeCache.getOption(perImporterKey)) {
        case (var result?,):
          return result;
        case (null,):
          continue;
      }

      switch (await _canonicalize(importer, url, baseUrl, forImport)) {
        case (var result?, true) when cacheable:
          _canonicalizeCache[key] = result;
          return result;

        case (var result, true) when !cacheable:
          _perImporterCanonicalizeCache[perImporterKey] = result;
          if (result != null) return result;

        case (var result, false):
          if (cacheable) {
            // If this is the first uncacheable result, add all previous results
            // to the per-importer cache so we don't have to re-run them for
            // future uses of this importer.
            for (var j = 0; j < i; j++) {
              _perImporterCanonicalizeCache[(
                _importers[j],
                url,
                forImport: forImport
              )] = null;
            }
            cacheable = false;
          }

          if (result != null) return result;
      }
    }

    if (cacheable) _canonicalizeCache[key] = null;
    return null;
  }

  /// Calls [importer.canonicalize] and prints a deprecation warning if it
  /// returns a relative URL.
  ///
  /// This returns both the result of the call to `canonicalize()` and whether
  /// that result is cacheable at all.
  Future<(AsyncCanonicalizeResult?, bool cacheable)> _canonicalize(
      AsyncImporter importer, Uri url, Uri? baseUrl, bool forImport) async {
    var passContainingUrl = baseUrl != null &&
        (url.scheme == '' || await importer.isNonCanonicalScheme(url.scheme));

    var canonicalizeContext =
        CanonicalizeContext(passContainingUrl ? baseUrl : null, forImport);

    var result = await withCanonicalizeContext(
        canonicalizeContext, () => importer.canonicalize(url));

    var cacheable =
        !passContainingUrl || !canonicalizeContext.wasContainingUrlAccessed;

    if (result == null) return (null, cacheable);

    if (result.scheme == '') {
      _logger.warnForDeprecation(
          Deprecation.relativeCanonical,
          "Importer $importer canonicalized $url to $result.\n"
          "Relative canonical URLs are deprecated and will eventually be "
          "disallowed.");
    } else if (await importer.isNonCanonicalScheme(result.scheme)) {
      throw "Importer $importer canonicalized $url to $result, which uses a "
          "scheme declared as non-canonical.";
    }

    return ((importer, result, originalUrl: url), cacheable);
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
  Future<(AsyncImporter, Stylesheet)?> import(Uri url,
      {AsyncImporter? baseImporter,
      Uri? baseUrl,
      bool forImport = false}) async {
    if (await canonicalize(url,
            baseImporter: baseImporter, baseUrl: baseUrl, forImport: forImport)
        case (var importer, var canonicalUrl, :var originalUrl)) {
      return (await importCanonical(importer, canonicalUrl,
              originalUrl: originalUrl))
          .andThen((stylesheet) => (importer, stylesheet));
    } else {
      return null;
    }
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
  Future<Stylesheet?> importCanonical(AsyncImporter importer, Uri canonicalUrl,
      {Uri? originalUrl, bool quiet = false}) async {
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
          logger: quiet ? Logger.quiet : _logger);
    });
  }

  /// Return a human-friendly URL for [canonicalUrl] to use in a stack trace.
  ///
  /// Returns [canonicalUrl] as-is if it hasn't been loaded by this cache.
  Uri humanize(Uri canonicalUrl) =>
      // If multiple original URLs canonicalize to the same thing, choose the
      // shortest one.
      minBy<Uri, int>(
              _canonicalizeCache.values.nonNulls
                  .where((result) => result.$2 == canonicalUrl)
                  .map((result) => result.originalUrl),
              (url) => url.path.length)
          // Use the canonicalized basename so that we display e.g.
          // package:example/_example.scss rather than package:example/example
          // in stack traces.
          .andThen((url) => url.resolve(p.url.basename(canonicalUrl.path))) ??
      // If we don't have an original URL cached, display the canonical URL
      // as-is.
      canonicalUrl;

  /// Returns the URL to use in the source map to refer to [canonicalUrl].
  ///
  /// Returns [canonicalUrl] as-is if it hasn't been loaded by this cache.
  Uri sourceMapUrl(Uri canonicalUrl) =>
      _resultsCache[canonicalUrl]?.sourceMapUrl ?? canonicalUrl;

  /// Clears the cached canonical version of the given non-canonical [url].
  ///
  /// Has no effect if the canonical version of [url] has not been cached.
  ///
  /// @nodoc
  @internal
  void clearCanonicalize(Uri url) {
    _canonicalizeCache.remove((url, forImport: false));
    _canonicalizeCache.remove((url, forImport: true));
    _perImporterCanonicalizeCache.removeWhere(
        (key, _) => key.$2 == url || _nonCanonicalRelativeUrls[key] == url);
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
