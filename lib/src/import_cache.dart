// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_import_cache.dart.
// See tool/synchronize.dart for details.
//
// Checksum: f499c5bf2076dd934ae3df7d133912401282c5c5

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
  /// This cache isn't used for relative imports, because they're
  /// context-dependent.
  final Map<Uri, Tuple2<Importer, Uri>> _canonicalizeCache;

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

  /// Returns the canonical form of [url] according to one of this cache's
  /// importers.
  ///
  /// If [baseImporter] is non-`null`, this first tries to use [baseImporter] to
  /// canonicalize [url] (resolved relative to [baseUrl] if it's passed).
  ///
  /// If any importers understand [url], returns that importer as well as the
  /// canonicalized URL. Otherwise, returns `null`.
  Tuple2<Importer, Uri> canonicalize(Uri url,
      [Importer baseImporter, Uri baseUrl]) {
    if (baseImporter != null) {
      var canonicalUrl = baseImporter
          .canonicalize(baseUrl != null ? baseUrl.resolveUri(url) : url);
      if (canonicalUrl != null) return new Tuple2(baseImporter, canonicalUrl);
    }

    return _canonicalizeCache.putIfAbsent(url, () {
      for (var importer in _importers) {
        var canonicalUrl = importer.canonicalize(url);
        if (canonicalUrl != null) return new Tuple2(importer, canonicalUrl);
      }

      return null;
    });
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
    var stylesheet = importCanonical(tuple.item1, tuple.item2, url);
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

      // Use the canonicalized basename so that we display e.g.
      // package:example/_example.scss rather than package:example/example in
      // stack traces.
      var displayUrl = originalUrl == null
          ? canonicalUrl
          : originalUrl.resolve(p.url.basename(canonicalUrl.path));
      return result.isIndented
          ? new Stylesheet.parseSass(result.contents,
              url: displayUrl, logger: _logger)
          : new Stylesheet.parseScss(result.contents,
              url: displayUrl, logger: _logger);
    });
  }
}
