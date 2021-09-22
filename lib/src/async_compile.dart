// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import 'package:path/path.dart' as p;

import 'ast/sass.dart';
import 'async_import_cache.dart';
import 'callable.dart';
import 'compile_result.dart';
import 'importer.dart';
import 'importer/legacy_node.dart';
import 'io.dart';
import 'logger.dart';
import 'logger/terse.dart';
import 'syntax.dart';
import 'utils.dart';
import 'visitor/async_evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compileAsync] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API and the executable.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
Future<CompileResult> compileAsync(String path,
    {Syntax? syntax,
    Logger? logger,
    AsyncImportCache? importCache,
    NodeImporter? nodeImporter,
    Iterable<AsyncCallable>? functions,
    OutputStyle? style,
    bool useSpaces = true,
    int? indentWidth,
    LineFeed? lineFeed,
    bool quietDeps = false,
    bool verbose = false,
    bool sourceMap = false,
    bool charset = true}) async {
  TerseLogger? terseLogger;
  if (!verbose) logger = terseLogger = TerseLogger(logger ?? Logger.stderr());

  // If the syntax is different than the importer would default to, we have to
  // parse the file manually and we can't store it in the cache.
  Stylesheet? stylesheet;
  if (nodeImporter == null &&
      (syntax == null || syntax == Syntax.forPath(path))) {
    importCache ??= AsyncImportCache.none(logger: logger);
    stylesheet = (await importCache.importCanonical(
        FilesystemImporter('.'), p.toUri(canonicalize(path)),
        originalUrl: p.toUri(path)))!;
  } else {
    stylesheet = Stylesheet.parse(
        readFile(path), syntax ?? Syntax.forPath(path),
        url: p.toUri(path), logger: logger);
  }

  var result = await _compileStylesheet(
      stylesheet,
      logger,
      importCache,
      nodeImporter,
      FilesystemImporter('.'),
      functions,
      style,
      useSpaces,
      indentWidth,
      lineFeed,
      quietDeps,
      sourceMap,
      charset);

  terseLogger?.summarize(node: nodeImporter != null);
  return result;
}

/// Like [compileStringAsync] in `lib/sass.dart`, but provides more options to
/// support the node-sass compatible API.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
Future<CompileResult> compileStringAsync(String source,
    {Syntax? syntax,
    Logger? logger,
    AsyncImportCache? importCache,
    NodeImporter? nodeImporter,
    Iterable<AsyncImporter>? importers,
    Iterable<String>? loadPaths,
    AsyncImporter? importer,
    Iterable<AsyncCallable>? functions,
    OutputStyle? style,
    bool useSpaces = true,
    int? indentWidth,
    LineFeed? lineFeed,
    Object? url,
    bool quietDeps = false,
    bool verbose = false,
    bool sourceMap = false,
    bool charset = true}) async {
  TerseLogger? terseLogger;
  if (!verbose) logger = terseLogger = TerseLogger(logger ?? Logger.stderr());

  var stylesheet =
      Stylesheet.parse(source, syntax ?? Syntax.scss, url: url, logger: logger);

  var result = await _compileStylesheet(
      stylesheet,
      logger,
      importCache,
      nodeImporter,
      importer ?? FilesystemImporter('.'),
      functions,
      style,
      useSpaces,
      indentWidth,
      lineFeed,
      quietDeps,
      sourceMap,
      charset);

  terseLogger?.summarize(node: nodeImporter != null);
  return result;
}

/// Compiles [stylesheet] and returns its result.
///
/// Arguments are handled as for [compileStringAsync].
Future<CompileResult> _compileStylesheet(
    Stylesheet stylesheet,
    Logger? logger,
    AsyncImportCache? importCache,
    NodeImporter? nodeImporter,
    AsyncImporter importer,
    Iterable<AsyncCallable>? functions,
    OutputStyle? style,
    bool useSpaces,
    int? indentWidth,
    LineFeed? lineFeed,
    bool quietDeps,
    bool sourceMap,
    bool charset) async {
  var evaluateResult = await evaluateAsync(stylesheet,
      importCache: importCache,
      nodeImporter: nodeImporter,
      importer: importer,
      functions: functions,
      logger: logger,
      quietDeps: quietDeps,
      sourceMap: sourceMap);

  var serializeResult = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed,
      sourceMap: sourceMap,
      charset: charset);

  var resultSourceMap = serializeResult.sourceMap;
  if (resultSourceMap != null && importCache != null) {
    // TODO(nweiz): Don't explicitly use a type parameter when dart-lang/sdk#25490
    // is fixed.
    mapInPlace<String>(
        resultSourceMap.urls,
        (url) => url == ''
            ? Uri.dataFromString(stylesheet.span.file.getText(0),
                    encoding: utf8)
                .toString()
            : importCache.sourceMapUrl(Uri.parse(url)).toString());
  }

  return CompileResult(evaluateResult, serializeResult);
}
