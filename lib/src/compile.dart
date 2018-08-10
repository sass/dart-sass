// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import 'ast/sass.dart';
import 'async_import_cache.dart';
import 'callable.dart';
import 'import_cache.dart';
import 'importer.dart';
import 'importer/node.dart';
import 'io.dart';
import 'logger.dart';
import 'sync_package_resolver.dart';
import 'syntax.dart';
import 'visitor/async_evaluate.dart';
import 'visitor/evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compile] in `lib/sass.dart`, but provides more options to support the
/// node-sass compatible API.
CompileResult compile(String path,
        {Syntax syntax,
        Logger logger,
        Iterable<Importer> importers,
        NodeImporter nodeImporter,
        SyncPackageResolver packageResolver,
        Iterable<String> loadPaths,
        Iterable<Callable> functions,
        OutputStyle style,
        bool useSpaces: true,
        int indentWidth,
        LineFeed lineFeed,
        bool sourceMap: false}) =>
    compileString(readFile(path),
        syntax: syntax ?? Syntax.forPath(path),
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
        url: p.toUri(path),
        sourceMap: sourceMap);

/// Like [compileString] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API.
CompileResult compileString(String source,
    {Syntax syntax,
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
    url,
    bool sourceMap: false}) {
  var stylesheet = new Stylesheet.parse(source, syntax ?? Syntax.scss,
      url: url, logger: logger);

  var evaluateResult = evaluate(stylesheet,
      importCache: new ImportCache(importers,
          loadPaths: loadPaths,
          packageResolver: packageResolver,
          logger: logger),
      nodeImporter: nodeImporter,
      importer: importer,
      functions: functions,
      logger: logger,
      sourceMap: sourceMap);

  var serializeResult = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed,
      sourceMap: sourceMap);

  return new CompileResult(evaluateResult, serializeResult);
}

/// Like [compileAsync] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API.
Future<CompileResult> compileAsync(String path,
        {Syntax syntax,
        Logger logger,
        Iterable<AsyncImporter> importers,
        NodeImporter nodeImporter,
        SyncPackageResolver packageResolver,
        Iterable<String> loadPaths,
        Iterable<AsyncCallable> functions,
        OutputStyle style,
        bool useSpaces: true,
        int indentWidth,
        LineFeed lineFeed,
        bool sourceMap: false}) =>
    compileStringAsync(readFile(path),
        syntax: syntax ?? Syntax.forPath(path),
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
        url: p.toUri(path),
        sourceMap: sourceMap);

/// Like [compileStringAsync] in `lib/sass.dart`, but provides more options to
/// support the node-sass compatible API.
Future<CompileResult> compileStringAsync(String source,
    {Syntax syntax,
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
    url,
    bool sourceMap: false}) async {
  var stylesheet = new Stylesheet.parse(source, syntax ?? Syntax.scss,
      url: url, logger: logger);

  var evaluateResult = await evaluateAsync(stylesheet,
      importCache: new AsyncImportCache(importers,
          loadPaths: loadPaths,
          packageResolver: packageResolver,
          logger: logger),
      nodeImporter: nodeImporter,
      importer: importer,
      functions: functions,
      logger: logger,
      sourceMap: sourceMap);

  var serializeResult = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed,
      sourceMap: sourceMap);

  return new CompileResult(evaluateResult, serializeResult);
}

/// The result of compiling a Sass document to CSS, along with metadata about
/// the compilation process.
class CompileResult {
  /// The result of evaluating the source file.
  final EvaluateResult _evaluate;

  /// The result of serializing the CSS AST to CSS text.
  final SerializeResult _serialize;

  /// The compiled CSS.
  String get css => _serialize.css;

  /// The source map indicating how the source files map to [css].
  ///
  /// This is `null` if source mapping was disabled for this compilation.
  SingleMapping get sourceMap => _serialize.sourceMap;

  /// A map from source file URLs to the corresponding [SourceFile]s.
  ///
  /// This can be passed to [sourceMap]'s [Mapping.spanFor] method. It's `null`
  /// if source mapping was disabled for this compilation.
  Map<String, SourceFile> get sourceFiles => _serialize.sourceFiles;

  /// The set that will eventually populate the JS API's
  /// `result.stats.includedFiles` field.
  ///
  /// For filesystem imports, this contains the import path. For all other
  /// imports, it contains the URL passed to the `@import`.
  Set<String> get includedFiles => _evaluate.includedFiles;

  CompileResult(this._evaluate, this._serialize);
}
