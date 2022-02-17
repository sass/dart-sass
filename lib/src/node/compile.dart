// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart' hide futureToPromise;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:tuple/tuple.dart';

import '../../sass.dart';
import '../ast/sass.dart';
import '../callable.dart';
import '../exception.dart';
import '../importer/no_op.dart';
import '../importer/node_to_dart/async.dart';
import '../importer/node_to_dart/async_file.dart';
import '../importer/node_to_dart/file.dart';
import '../importer/node_to_dart/sync.dart';
import '../io.dart';
import '../logger/node_to_dart.dart';
import '../parse/scss.dart';
import '../util/nullable.dart';
import '../utils.dart';
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
        importers: options?.importers?.map(_parseImporter),
        functions: _parseFunctions(options?.functions).cast());
    return _convertResult(result,
        includeSourceContents: options?.sourceMapIncludeSources ?? false);
  } on SassException catch (error, stackTrace) {
    throwNodeException(error, color: color, ascii: ascii, trace: stackTrace);
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
            (options?.url == null ? NoOpImporter() : null),
        functions: _parseFunctions(options?.functions).cast());
    return _convertResult(result,
        includeSourceContents: options?.sourceMapIncludeSources ?? false);
  } on SassException catch (error, stackTrace) {
    throwNodeException(error, color: color, ascii: ascii, trace: stackTrace);
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
            ?.map((importer) => _parseAsyncImporter(importer)),
        functions: _parseFunctions(options?.functions, asynch: true));
    return _convertResult(result,
        includeSourceContents: options?.sourceMapIncludeSources ?? false);
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
            (options?.url == null ? NoOpImporter() : null),
        functions: _parseFunctions(options?.functions, asynch: true));
    return _convertResult(result,
        includeSourceContents: options?.sourceMapIncludeSources ?? false);
  }()), color: color, ascii: ascii);
}

/// Converts a Dart [CompileResult] into a JS API [NodeCompileResult].
NodeCompileResult _convertResult(CompileResult result,
    {required bool includeSourceContents}) {
  var sourceMap =
      result.sourceMap?.toJson(includeSourceContents: includeSourceContents);
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

/// Parses `functions` from [record] into a list of [Callable]s or
/// [AsyncCallable]s.
///
/// This is typed to always return [AsyncCallable], but in practice it will
/// return a `List<Callable>` if [asynch] is `false`.
List<AsyncCallable> _parseFunctions(Object? functions, {bool asynch = false}) {
  if (functions == null) return const [];

  var result = <AsyncCallable>[];
  jsForEach(functions, (signature, callback) {
    Tuple2<String, ArgumentDeclaration> tuple;
    try {
      tuple = ScssParser(signature).parseSignature();
    } on SassFormatException catch (error, stackTrace) {
      throwWithTrace(
          SassFormatException(
              'Invalid signature "$signature": ${error.message}', error.span),
          stackTrace);
    }

    if (!asynch) {
      result.add(BuiltInCallable.parsed(tuple.item1, tuple.item2, (arguments) {
        var result = (callback as Function)(toJSArray(arguments));
        if (result is Value) return result;
        if (isPromise(result)) {
          throw 'Invalid return value for custom function '
              '"${tuple.item1}":\n'
              'Promises may only be returned for sass.compileAsync() and '
              'sass.compileStringAsync().';
        } else {
          throw 'Invalid return value for custom function '
              '"${tuple.item1}": $result is not a sass.Value.';
        }
      }));
    } else {
      result.add(AsyncBuiltInCallable.parsed(tuple.item1, tuple.item2,
          (arguments) async {
        var result = (callback as Function)(toJSArray(arguments));
        if (isPromise(result)) {
          result = await promiseToFuture<Object>(result as Promise);
        }

        if (result is Value) return result;
        throw 'Invalid return value for custom function '
            '"${tuple.item1}": $result is not a sass.Value.';
      }));
    }
  });
  return result;
}
