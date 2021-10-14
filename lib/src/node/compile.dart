// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import '../../sass.dart';
import '../importer/no_op.dart';
import '../importer/node_to_dart/async.dart';
import '../importer/node_to_dart/async_file.dart';
import '../importer/node_to_dart/file.dart';
import '../importer/node_to_dart/sync.dart';
import '../io.dart';
import '../logger.dart';
import '../logger/node_to_dart.dart';
import '../util/nullable.dart';
import 'compile_options.dart';
import 'compile_result.dart';
import 'exception.dart';
import 'importer.dart';
import 'utils.dart';

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
NodeCompileResult compile(String path, [CompileOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  try {
    var result = compileToResult(path,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false,
        logger: NodeToDartLogger(options?.logger, Logger.stderr(color: color),
            ascii: ascii),
        importers: options?.importers?.map(_parseImporter));
    return _convertResult(result);
  } on SassException catch (error) {
    throwNodeException(error, color: color, ascii: ascii);
  }
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
NodeCompileResult compileString(String text, [CompileStringOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  try {
    var result = compileStringToResult(text,
        syntax: parseSyntax(options?.syntax),
        url: options?.url.andThen(jsToDartUrl),
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false,
        logger: NodeToDartLogger(options?.logger, Logger.stderr(color: color),
            ascii: ascii),
        importers: options?.importers?.map(_parseImporter),
        importer: options?.importer.andThen(_parseImporter) ??
            (options?.url == null ? NoOpImporter() : null));
    return _convertResult(result);
  } on SassException catch (error) {
    throwNodeException(error, color: color, ascii: ascii);
  }
}

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise compileAsync(String path, [CompileOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  return _wrapAsyncSassExceptions(futureToPromise(() async {
    var result = await compileToResultAsync(path,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false,
        logger: NodeToDartLogger(options?.logger, Logger.stderr(color: color),
            ascii: ascii),
        importers: options?.importers
            ?.map((importer) => _parseAsyncImporter(importer)));
    return _convertResult(result);
  }()), color: color, ascii: ascii);
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise compileStringAsync(String text, [CompileStringOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  var ascii = options?.alertAscii ?? glyph.ascii;
  return _wrapAsyncSassExceptions(futureToPromise(() async {
    var result = await compileStringToResultAsync(text,
        syntax: parseSyntax(options?.syntax),
        url: options?.url.andThen(jsToDartUrl),
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false,
        logger: NodeToDartLogger(options?.logger, Logger.stderr(color: color),
            ascii: ascii),
        importers: options?.importers
            ?.map((importer) => _parseAsyncImporter(importer)),
        importer: options?.importer
                .andThen((importer) => _parseAsyncImporter(importer)) ??
            (options?.url == null ? NoOpImporter() : null));
    return _convertResult(result);
  }()), color: color, ascii: ascii);
}

/// Converts a Dart [CompileResult] into a JS API [NodeCompileResult].
NodeCompileResult _convertResult(CompileResult result) {
  var sourceMap = result.sourceMap?.toJson();
  if (sourceMap is Map<String, dynamic> && !sourceMap.containsKey('sources')) {
    // Dart's source map library can omit the sources key, but JS's type
    // declaration doesn't allow that.
    sourceMap['sources'] = <String>[];
  }

  var loadedUrls = toJSArray(result.loadedUrls.map(dartToJSUrl));
  return sourceMap == null
      // The JS API tests expects *no* source map here, not a null source map.
      ? NodeCompileResult(css: result.css, loadedUrls: loadedUrls)
      : NodeCompileResult(
          css: result.css, loadedUrls: loadedUrls, sourceMap: jsify(sourceMap));
}

/// Catches `SassException`s thrown by [promise] and rethrows them as JS API
/// exceptions.
Promise _wrapAsyncSassExceptions(Promise promise,
        {required bool color, required bool ascii}) =>
    promise.then(
        null,
        allowInterop((error) => error is SassException
            ? throwNodeException(error, color: color, ascii: ascii)
            : jsThrow(error as Object)));

/// Converts an output style string to an instance of [OutputStyle].
OutputStyle _parseOutputStyle(String? style) {
  if (style == null || style == 'expanded') return OutputStyle.expanded;
  if (style == 'compressed') return OutputStyle.compressed;
  jsThrow(JsError('Unknown output style "$style".'));
}

/// Converts [importer] into an [AsyncImporter] that can be used with
/// [compileAsync] or [compileStringAsync].
AsyncImporter _parseAsyncImporter(Object? importer) {
  if (importer == null) jsThrow(JsError("Importers may not be null."));

  importer as NodeImporter;
  var findFileUrl = importer.findFileUrl;
  var canonicalize = importer.canonicalize;
  var load = importer.load;
  if (findFileUrl == null) {
    if (canonicalize == null || load == null) {
      jsThrow(JsError(
          "An importer must have either canonicalize and load methods, or a "
          "findFileUrl method."));
    }
    return NodeToDartAsyncImporter(canonicalize, load);
  } else if (canonicalize != null || load != null) {
    jsThrow(JsError("An importer may not have a findFileUrl method as well as "
        "canonicalize and load methods."));
  } else {
    return NodeToDartAsyncFileImporter(findFileUrl);
  }
}

/// Converts [importer] into a synchronous [Importer].
Importer _parseImporter(Object? importer) {
  if (importer == null) jsThrow(JsError("Importers may not be null."));

  importer as NodeImporter;
  var findFileUrl = importer.findFileUrl;
  var canonicalize = importer.canonicalize;
  var load = importer.load;
  if (findFileUrl == null) {
    if (canonicalize == null || load == null) {
      jsThrow(JsError(
          "An importer must have either canonicalize and load methods, or a "
          "findFileUrl method."));
    }
    return NodeToDartImporter(canonicalize, load);
  } else if (canonicalize != null || load != null) {
    jsThrow(JsError("An importer may not have a findFileUrl method as well as "
        "canonicalize and load methods."));
  } else {
    return NodeToDartFileImporter(findFileUrl);
  }
}
