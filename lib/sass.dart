// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'src/callable.dart';
import 'src/compile.dart' as c;
import 'src/exception.dart';
import 'src/importer.dart';
import 'src/sync_package_resolver.dart';

export 'src/callable.dart' show Callable, AsyncCallable;
export 'src/importer.dart';
export 'src/value.dart' show ListSeparator;
export 'src/value/external/value.dart';

/// Loads the Sass file at [path], compiles it to CSS, and returns the result.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// Imports are resolved by trying, in order:
///
/// * Loading a file relative to [path].
///
/// * Each importer in [importers].
///
/// * Each load path in [loadPaths]. Note that this is a shorthand for adding
///   [FilesystemImporter]s to [importers].
///
/// * `package:` resolution using [packageResolver], which is a
///   [SyncPackageResolver][] from the `package_resolver` package. Note that
///   this is a shorthand for adding a [PackageImporter] to [importers].
///
/// [SyncPackageResolver]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
///
/// Dart functions that can be called from Sass may be passed using [functions].
/// Each [Callable] defines a top-level function that will be invoked when the
/// given name is called from Sass.
///
/// Throws a [SassException] if conversion fails.
String compile(String path,
    {bool color: false,
    Iterable<Importer> importers,
    Iterable<String> loadPaths,
    SyncPackageResolver packageResolver,
    Iterable<Callable> functions}) {
  var result = c.compile(path,
      color: color,
      importers: importers,
      loadPaths: loadPaths,
      packageResolver: packageResolver,
      functions: functions);
  return result.css;
}

/// Compiles [source] to CSS and returns the result.
///
/// If [indented] is `true`, this parses [source] using indented syntax;
/// otherwise (and by default) it uses SCSS. If [color] is `true`, this will use
/// terminal colors in warnings.
///
/// Imports are resolved by trying, in order:
///
/// * The given [importer], with the imported URL resolved relative to [url].
///
/// * Each importer in [importers].
///
/// * Each load path in [loadPaths]. Note that this is a shorthand for adding
///   [FilesystemImporter]s to [importers].
///
/// * `package:` resolution using [packageResolver], which is a
///   [SyncPackageResolver][] from the `package_resolver` package. Note that
///   this is a shorthand for adding a [PackageImporter] to [importers].
///
/// [SyncPackageResolver]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
///
/// Dart functions that can be called from Sass may be passed using [functions].
/// Each [Callable] defines a top-level function that will be invoked when the
/// given name is called from Sass.
///
/// The [url] indicates the location from which [source] was loaded. It may be a
/// [String] or a [Uri]. If [importer] is passed, [url] must be passed as well
/// and `importer.load(url)` should return `source`.
///
/// Throws a [SassException] if conversion fails.
String compileString(String source,
    {bool indented: false,
    bool color: false,
    Iterable<Importer> importers,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    Iterable<Callable> functions,
    Importer importer,
    url}) {
  var result = c.compileString(source,
      indented: indented,
      color: color,
      importers: importers,
      packageResolver: packageResolver,
      loadPaths: loadPaths,
      functions: functions,
      importer: importer,
      url: url);
  return result.css;
}

/// Like [compile], except it runs asynchronously.
///
/// Running asynchronously allows this to take [AsyncImporter]s rather than
/// synchronous [Importer]s. However, running asynchronously is also somewhat
/// slower, so [compile] should be preferred if possible.
Future<String> compileAsync(String path,
    {bool color: false,
    Iterable<AsyncImporter> importers,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    Iterable<AsyncCallable> functions}) async {
  var result = await c.compileAsync(path,
      color: color,
      importers: importers,
      loadPaths: loadPaths,
      packageResolver: packageResolver,
      functions: functions);
  return result.css;
}

/// Like [compileString], except it runs asynchronously.
///
/// Running asynchronously allows this to take [AsyncImporter]s rather than
/// synchronous [Importer]s. However, running asynchronously is also somewhat
/// slower, so [compileString] should be preferred if possible.
Future<String> compileStringAsync(String source,
    {bool indented: false,
    bool color: false,
    Iterable<AsyncImporter> importers,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    Iterable<AsyncCallable> functions,
    AsyncImporter importer,
    url}) async {
  var result = await c.compileStringAsync(source,
      indented: indented,
      color: color,
      importers: importers,
      packageResolver: packageResolver,
      loadPaths: loadPaths,
      functions: functions,
      importer: importer,
      url: url);
  return result.css;
}

/// Use [compile] instead.
@Deprecated('Will be removed in 1.0.0')
String render(String path,
        {bool color: false, SyncPackageResolver packageResolver}) =>
    compile(path, color: color, packageResolver: packageResolver);
