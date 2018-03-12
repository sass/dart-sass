// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'ast/sass.dart';
import 'callable.dart';
import 'importer.dart';
import 'importer/node.dart';
import 'io.dart';
import 'logger.dart';
import 'sync_package_resolver.dart';
import 'util/path.dart';
import 'visitor/async_evaluate.dart';
import 'visitor/evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compile] in `lib/sass.dart`, but provides more options to support the
/// node-sass compatible API.
CompileResult compile(String path,
        {bool indented,
        Logger logger,
        Iterable<Importer> importers,
        NodeImporter nodeImporter,
        SyncPackageResolver packageResolver,
        Iterable<String> loadPaths,
        Iterable<Callable> functions,
        OutputStyle style,
        bool useSpaces: true,
        int indentWidth,
        LineFeed lineFeed}) =>
    compileString(readFile(path),
        indented: indented ?? p.extension(path) == '.sass',
        logger: logger,
        functions: functions,
        importers: importers,
        nodeImporter: nodeImporter,
        packageResolver: packageResolver,
        loadPaths: loadPaths,
        importer: new FilesystemImporter('.'),
        style: style,
        useSpaces: useSpaces,
        indentWidth: indentWidth,
        lineFeed: lineFeed,
        url: p.toUri(path));

/// Like [compileString] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API.
CompileResult compileString(String source,
    {bool indented: false,
    Logger logger,
    Iterable<Importer> importers,
    NodeImporter nodeImporter,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    Importer importer,
    Iterable<Callable> functions,
    OutputStyle style,
    bool useSpaces: true,
    int indentWidth,
    LineFeed lineFeed,
    url}) {
  var sassTree = indented
      ? new Stylesheet.parseSass(source, url: url, logger: logger)
      : new Stylesheet.parseScss(source, url: url, logger: logger);

  var evaluateResult = evaluate(sassTree,
      importers: (importers?.toList() ?? [])
        ..addAll(_toImporters(loadPaths, packageResolver)),
      nodeImporter: nodeImporter,
      importer: importer,
      functions: functions,
      logger: logger);
  var css = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed);

  return new CompileResult(css, evaluateResult.includedFiles);
}

/// Like [compileAsync] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API.
Future<CompileResult> compileAsync(String path,
        {bool indented,
        Logger logger,
        Iterable<AsyncImporter> importers,
        NodeImporter nodeImporter,
        SyncPackageResolver packageResolver,
        Iterable<String> loadPaths,
        Iterable<AsyncCallable> functions,
        OutputStyle style,
        bool useSpaces: true,
        int indentWidth,
        LineFeed lineFeed}) =>
    compileStringAsync(readFile(path),
        indented: indented ?? p.extension(path) == '.sass',
        logger: logger,
        importers: importers,
        nodeImporter: nodeImporter,
        packageResolver: packageResolver,
        loadPaths: loadPaths,
        importer: new FilesystemImporter('.'),
        functions: functions,
        style: style,
        useSpaces: useSpaces,
        indentWidth: indentWidth,
        lineFeed: lineFeed,
        url: p.toUri(path));

/// Like [compileStringAsync] in `lib/sass.dart`, but provides more options to
/// support the node-sass compatible API.
Future<CompileResult> compileStringAsync(String source,
    {bool indented: false,
    Logger logger,
    Iterable<AsyncImporter> importers,
    NodeImporter nodeImporter,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    AsyncImporter importer,
    Iterable<AsyncCallable> functions,
    OutputStyle style,
    bool useSpaces: true,
    int indentWidth,
    LineFeed lineFeed,
    url}) async {
  var sassTree = indented
      ? new Stylesheet.parseSass(source, url: url, logger: logger)
      : new Stylesheet.parseScss(source, url: url, logger: logger);

  var evaluateResult = await evaluateAsync(sassTree,
      importers: (importers?.toList() ?? [])
        ..addAll(_toImporters(loadPaths, packageResolver)),
      nodeImporter: nodeImporter,
      importer: importer,
      functions: functions,
      logger: logger);
  var css = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed);

  return new CompileResult(css, evaluateResult.includedFiles);
}

/// Converts the user's [loadPaths] and [packageResolver] options into
/// importers.
List<Importer> _toImporters(
    Iterable<String> loadPaths, SyncPackageResolver packageResolver) {
  var list = <Importer>[];
  if (loadPaths != null) {
    list.addAll(loadPaths.map((path) => new FilesystemImporter(path)));
  }
  if (packageResolver != null) {
    list.add(new PackageImporter(packageResolver));
  }
  return list;
}

/// The result of compiling a Sass document to CSS, along with metadata about
/// the compilation process.
class CompileResult {
  /// The compiled CSS.
  final String css;

  /// The set that will eventually populate the JS API's
  /// `result.stats.includedFiles` field.
  ///
  /// For filesystem imports, this contains the import path. For all other
  /// imports, it contains the URL passed to the `@import`.
  final Set<String> includedFiles;

  CompileResult(this.css, this.includedFiles);
}
