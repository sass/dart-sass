// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';

import '../../sass.dart';
import '../importer/no_op.dart';
import '../io.dart';
import '../util/nullable.dart';
import 'compile_options.dart';
import 'compile_result.dart';
import 'exception.dart';
import 'utils.dart';

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
NodeCompileResult compile(String path, [CompileOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  try {
    var result = compileToResult(path,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false);
    return _convertResult(result);
  } on SassException catch (error) {
    throwNodeException(error, color: color);
  }
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
NodeCompileResult compileString(String text, [CompileStringOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  try {
    var result = compileStringToResult(text,
        syntax: _parseSyntax(options?.syntax),
        url: options?.url.andThen(jsToDartUrl),
        importer: options?.url == null ? NoOpImporter() : null,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false);
    return _convertResult(result);
  } on SassException catch (error) {
    throwNodeException(error, color: color);
  }
}

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise compileAsync(String path, [CompileOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  return _wrapAsyncSassExceptions(futureToPromise(() async {
    var result = await compileToResultAsync(path,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false);
    return _convertResult(result);
  }()), color: color);
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
Promise compileStringAsync(String text, [CompileStringOptions? options]) {
  var color = options?.alertColor ?? hasTerminal;
  return _wrapAsyncSassExceptions(futureToPromise(() async {
    var result = await compileStringToResultAsync(text,
        syntax: _parseSyntax(options?.syntax),
        url: options?.url.andThen(jsToDartUrl),
        importer: options?.url == null ? NoOpImporter() : null,
        color: color,
        loadPaths: options?.loadPaths,
        quietDeps: options?.quietDeps ?? false,
        style: _parseOutputStyle(options?.style),
        verbose: options?.verbose ?? false,
        sourceMap: options?.sourceMap ?? false);
    return _convertResult(result);
  }()), color: color);
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
Promise _wrapAsyncSassExceptions(Promise promise, {required bool color}) =>
    promise.then(
        null,
        allowInterop((error) => error is SassException
            ? throwNodeException(error, color: color)
            : jsThrow(error as Object)));

/// Converts an output style string to an instance of [OutputStyle].
OutputStyle _parseOutputStyle(String? style) {
  if (style == null || style == 'expanded') return OutputStyle.expanded;
  if (style == 'compressed') return OutputStyle.compressed;
  jsThrow(JsError('Unknown output style "$style".'));
}

/// Converts a syntax string to an instance of [Syntax].
Syntax _parseSyntax(String? syntax) {
  if (syntax == null || syntax == 'scss') return Syntax.scss;
  if (syntax == 'indented') return Syntax.sass;
  if (syntax == 'css') return Syntax.css;
  jsThrow(JsError('Unknown syntax "$syntax".'));
}
