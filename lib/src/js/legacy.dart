// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cli_pkg/js.dart';
import 'package:js_core/js_core.dart';
import 'package:path/path.dart' as p;

import '../async_import_cache.dart';
import '../import_cache.dart';
import '../importer/node_package.dart';
import '../callable.dart';
import '../compile.dart';
import '../compile_result.dart';
import '../exception.dart';
import '../importer/legacy_node.dart';
import '../io.dart';
import '../logger.dart';
import '../logger/js_to_dart.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../utils.dart';
import '../value.dart';
import '../visitor/serialize.dart';
import 'deprecation.dart';
import 'extension/error.dart';
import 'function.dart';
import 'legacy/render_context.dart';
import 'legacy/render_options.dart';
import 'legacy/render_result.dart';
import 'legacy/value.dart';
import 'utils.dart';

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `render()` API][render] as closely as
/// possible.
///
/// [render]: https://github.com/sass/node-sass#options
void render(RenderOptions options, JSFunction callback) {
  if (!isNodeJs) {
    JSError.throwLikeJS(
        JSError("The render() method is only available in Node.js."));
  }
    _renderAsync(options).then(
      (result) {
        callback.callAsFunction(null, null, result);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (error is SassException) {
          callback.callAsFunction(null, _wrapException(error, stackTrace), null);
        } else {
          callback.callAsFunction(null,
            RenderError(
              error.toString(),
              getTrace(error) ?? stackTrace,
              status: 3,
            ),
            null,
          );
        }
      },
    );
}

/// Converts Sass to CSS asynchronously.
Future<RenderResult> _renderAsync(RenderOptions options) async {
  var start = DateTime.now();
  CompileResult result;

  var file = options.file.andThen(p.absolute);
  var logger = options.logger(Logger.stderr(color: hasTerminal));
  if (options.data case var data?) {
    result = await compileStringAsync(
      data,
      nodeImporter: options.importer(start),
      importCache: options.pkgImporterAsyncCache,
      functions: _parseFunctions(options, start, asynch: true),
      syntax: options.indentedSyntax.isTruthy ? Syntax.sass : null,
      style: options.outputStyle,
      useSpaces: options.indentType != 'tab',
      indentWidth: options.indentWidth,
      lineFeed: options.lineFeed,
      url: file == null ? 'stdin' : p.toUri(file).toString(),
      quietDeps: options.quietDeps,
      fatalDeprecations(logger): options.fatalDeprecations(logger),
      futureDeprecations(logger): options.futureDeprecations(logger),
      silenceDeprecations(logger): options.silenceDeprecations(logger),
      verbose: options.verbose,
      charset: options.charset,
      sourceMap: options.enableSourceMaps,
      logger: logger,
    );
  } else if (file != null) {
    result = await compileAsync(
      file,
      nodeImporter: options.importer(start),
      importCache: options.pkgImporterAsyncCache,
      functions: _parseFunctions(options, start, asynch: true),
      syntax: options.indentedSyntax.isTruthy ? Syntax.sass : null,
      style: options.outputStyle,
      useSpaces: options.indentType != 'tab',
      indentWidth: options.indentWidth,
      lineFeed: options.lineFeed,
      quietDeps: options.quietDeps,
      fatalDeprecations(logger): options.fatalDeprecations(logger),
      futureDeprecations(logger): options.futureDeprecations(logger),
      silenceDeprecations(logger): options.silenceDeprecations(logger),
      verbose: options.verbose,
      charset: options.charset,
      sourceMap: options.enableSourceMaps,
      logger: logger,
    );
  } else {
    throw ArgumentError("Either options.data or options.file must be set.");
  }

  return RenderResult(options, result, start);
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `renderSync()` API][render] as closely
/// as possible.
///
/// [render]: https://github.com/sass/node-sass#options
RenderResult renderSync(RenderOptions options) {
  if (!isNodeJs) {
    JSError.throwLikeJS(
        JSError("The renderSync() method is only available in Node.js."));
  }
  try {
    var start = DateTime.now();
    CompileResult result;

    var file = options.file.andThen(p.absolute);
    var logger = options.logger(Logger.stderr(color: hasTerminal));
    if (options.data case var data?) {
      result = compileString(
        data,
        nodeImporter: options.importer(start),
        importCache: options.pkgImporterCache,
        functions: _parseFunctions(options, start).cast(),
        syntax: options.indentedSyntax.isTruthy ? Syntax.sass : null,
        style: options.outputStyle,
        useSpaces: options.indentType != 'tab',
        indentWidth: options.indentWidth,
        lineFeed: options.lineFeed,
        url: file == null ? 'stdin' : p.toUri(file).toString(),
        quietDeps: options.quietDeps,
        fatalDeprecations(logger): options.fatalDeprecations(logger),
        futureDeprecations(logger): options.futureDeprecations(logger),
        silenceDeprecations(logger): options.silenceDeprecations(logger),
        verbose: options.verbose,
        charset: options.charset,
        sourceMap: options.enableSourceMaps,
        logger: logger,
      );
    } else if (file != null) {
      result = compile(
        file,
        nodeImporter: options.importer(start),
        importCache: options.pkgImporterCache,
        functions: _parseFunctions(options, start).cast(),
        syntax: options.indentedSyntax.isTruthy ? Syntax.sass : null,
        style: options.outputStyle,
        useSpaces: options.indentType != 'tab',
        indentWidth: options.indentWidth,
        lineFeed: options.lineFeed,
        quietDeps: options.quietDeps,
        fatalDeprecations(logger): options.fatalDeprecations(logger),
        futureDeprecations(logger): options.futureDeprecations(logger),
        silenceDeprecations(logger): options.silenceDeprecations(logger),
        verbose: options.verbose,
        charset: options.charset,
        sourceMap: options.enableSourceMaps,
        logger: logger,
      );
    } else {
      throw ArgumentError("Either options.data or options.file must be set.");
    }

    return RenderResult(options, result, start);
  } on SassException catch (error, stackTrace) {
    JSError.throwLikeJS(_wrapException(error, stackTrace));
  } catch (error, stackTrace) {
    JSError.throwLikeJS(
      RenderError(
        error.toString(),
        getTrace(error) ?? stackTrace,
        status: 3,
      ),
    );
  }
}

/// Converts an exception to a [JSError].
JSError _wrapException(Object exception, StackTrace stackTrace) {
  if (exception is SassException) {
    var file = switch (exception.span.sourceUrl) {
      null => 'stdin',
      Uri(scheme: 'file') && var url => p.fromUri(url),
      var url => url.toString(),
    };

    return RenderError(
      exception.toString().replaceFirst("Error: ", ""),
      getTrace(exception) ?? stackTrace,
      line: exception.span.start.line + 1,
      column: exception.span.start.column + 1,
      file: file,
      status: 1,
    );
  } else {
    return JSError(exception.toString())
    ..attachStackTrace(getTrace(exception) ?? stackTrace);
  }
}
