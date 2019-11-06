// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import 'ast/sass.dart';
import 'async_import_cache.dart';
import 'callable.dart';
import 'importer.dart';
import 'importer/node.dart';
import 'io.dart';
import 'logger.dart';
import 'sync_package_resolver.dart';
import 'syntax.dart';
import 'utils.dart';
import 'visitor/async_evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compileAsync] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API and the executable.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
Future<CompileResult> compileAsync(String path,
    {Syntax syntax,
    Logger logger,
    AsyncImportCache importCache,
    NodeImporter nodeImporter,
    Iterable<AsyncCallable> functions,
    OutputStyle style,
    bool useSpaces = true,
    int indentWidth,
    LineFeed lineFeed,
    bool sourceMap = false,
    bool charset = true}) async {
  // If the syntax is different than the importer would default to, we have to
  // parse the file manually and we can't store it in the cache.
  Stylesheet stylesheet;
  if (nodeImporter == null &&
      (syntax == null || syntax == Syntax.forPath(path))) {
    importCache ??= AsyncImportCache.none(logger: logger);
    stylesheet = await importCache.importCanonical(
        FilesystemImporter('.'), p.toUri(p.canonicalize(path)), p.toUri(path));
  } else {
    stylesheet = Stylesheet.parse(
        readFile(path), syntax ?? Syntax.forPath(path),
        url: p.toUri(path), logger: logger);
  }

  return await _compileStylesheet(
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
      sourceMap,
      charset);
}

/// Like [compileStringAsync] in `lib/sass.dart`, but provides more options to
/// support the node-sass compatible API.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
Future<CompileResult> compileStringAsync(String source,
    {Syntax syntax,
    Logger logger,
    AsyncImportCache importCache,
    NodeImporter nodeImporter,
    Iterable<AsyncImporter> importers,
    Iterable<String> loadPaths,
    SyncPackageResolver packageResolver,
    AsyncImporter importer,
    Iterable<AsyncCallable> functions,
    OutputStyle style,
    bool useSpaces = true,
    int indentWidth,
    LineFeed lineFeed,
    Object url,
    bool sourceMap = false,
    bool charset = true}) async {
  var stylesheet =
      Stylesheet.parse(source, syntax ?? Syntax.scss, url: url, logger: logger);

  return _compileStylesheet(
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
      sourceMap,
      charset);
}

/// Compiles [stylesheet] and returns its result.
///
/// Arguments are handled as for [compileStringAsync].
Future<CompileResult> _compileStylesheet(
    Stylesheet stylesheet,
    Logger logger,
    AsyncImportCache importCache,
    NodeImporter nodeImporter,
    AsyncImporter importer,
    Iterable<AsyncCallable> functions,
    OutputStyle style,
    bool useSpaces,
    int indentWidth,
    LineFeed lineFeed,
    bool sourceMap,
    bool charset) async {
  var evaluateResult = await evaluateAsync(stylesheet,
      importCache: importCache,
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
      sourceMap: sourceMap,
      charset: charset);

  if (serializeResult.sourceMap != null && importCache != null) {
    // TODO(nweiz): Don't explicitly use a type parameter when dart-lang/sdk#25490
    // is fixed.
    mapInPlace<String>(
        serializeResult.sourceMap.urls,
        (url) => url == ''
            ? Uri.dataFromString(stylesheet.span.file.getText(0),
                    encoding: utf8)
                .toString()
            : importCache.sourceMapUrl(Uri.parse(url)).toString());
  }

  return CompileResult(evaluateResult, serializeResult);
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
