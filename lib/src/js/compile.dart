// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:cli_pkg/js.dart';
import 'package:js_core/js_core.dart';
import 'package:node_interop/js.dart' hide Promise;
import 'package:node_interop/util.dart' hide futureToPromise;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:path/path.dart' as p;

import '../../sass.dart' hide Deprecation;
import '../importer/no_op.dart';
import '../importer/js_to_dart/async.dart';
import '../importer/js_to_dart/async_file.dart';
import '../importer/js_to_dart/file.dart';
import '../importer/js_to_dart/sync.dart';
import '../io.dart';
import '../logger/js_to_dart.dart';
import '../util/nullable.dart';
import 'compile_options.dart';
import 'compile_result.dart';
import 'deprecation.dart';
import 'hybrid/node_importer.dart';
import 'importer.dart';
import 'sass_exception.dart';
import 'utils.dart';

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
JSCompileResult compile(String path, [SyncCompileOptions? options]) {
  options ??= SyncCompileOptions();

  if (!isNodeJs) {
    JSError.throwLikeJS(
        JSError("The compile() method is only available in Node.js."));
  }
  var color = options.alertColor;
  var ascii = options.alertAscii;
  var logger = options.logger(Logger.stderr(color: color), ascii: ascii);
  try {
    var result = compileToResult(
      path,
      color: color,
      loadPaths: options.loadPaths?.toDart,
      quietDeps: options.quietDeps,
      style: options.outputStyle,
      verbose: options.verbose,
      charset: options.charset,
      sourceMap: options.sourceMap,
      logger: logger,
      importers: options.importers,
      functions: options.functions,
      fatalDeprecations: options.fatalDeprecations(logger),
      silenceDeprecations: options.silenceDeprecations(logger),
      futureDeprecations: options.futureDeprecations(logger),
    );
    return result.toJS(
      includeSourceContents: options.sourceMapIncludeSources,
    );
  } on SassException catch (error, stackTrace) {
    JSError.throwLikeJS(
        JSSassException(error, color: color, ascii: ascii, trace: stackTrace));
  }
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
JSCompileResult compileString(String text, [SyncCompileOptions? options]) {
  options ??= SyncCompileOptions();

  var color = options.alertColor;
  var ascii = options.alertAscii;
  var logger = options.logger(Logger.stderr(color: color), ascii: ascii);
  try {
    var result = compileStringToResult(
      text,
      syntax: options.syntax,
      url: options.url,
      color: color,
      loadPaths: options.loadPaths?.toDart,
      quietDeps: options.quietDeps,
      style: options.outputStyle,
      verbose: options.verbose,
      charset: options.charset,
      sourceMap: options.sourceMap,
      logger: logger,
      importers: options.importers,
      importer: options.importer,
      functions: options.functions,
      fatalDeprecations: options.fatalDeprecations(logger),
      silenceDeprecations: options.silenceDeprecations(logger),
      futureDeprecations: options.futureDeprecations(logger),
    );
    return result.toJS(
      includeSourceContents: options.sourceMapIncludeSources,
    );
  } on SassException catch (error, stackTrace) {
    JSError.throwLikeJS(
        JSSassException(error, color: color, ascii: ascii, trace: stackTrace));
  }
}

/// The JS API `compile` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
JSPromise<JSCompileResult> compileAsync(String path,
    [AsyncCompileOptions? options_]) {
  var options = options_ ?? AsyncCompileOptions();

  return Future.sync(() async {
    if (!isNodeJs) {
      JSError.throwLikeJS(
          JSError("The compileAsync() method is only available in Node.js."));
    }
    var color = options.alertColor;
    var ascii = options.alertAscii;
    var logger = options.logger(Logger.stderr(color: color), ascii: ascii);
    try {
      var result = await compileToResultAsync(
        path,
        color: color,
        loadPaths: options.loadPaths?.toDart,
        quietDeps: options.quietDeps,
        style: options.outputStyle,
        verbose: options.verbose,
        charset: options.charset,
        sourceMap: options.sourceMap,
        logger: logger,
        importers: options.asyncImporters,
        functions: options.asyncFunctions,
        fatalDeprecations: options.fatalDeprecations(logger),
        silenceDeprecations: options.silenceDeprecations(logger),
        futureDeprecations: options.futureDeprecations(logger),
      );
      return result.toJS(
        includeSourceContents: options.sourceMapIncludeSources,
      );
    } on SassException catch (error, stackTrace) {
      throw JSSassException(error,
          color: color, ascii: ascii, trace: stackTrace);
    }
  }).toJS;
}

/// The JS API `compileString` function.
///
/// See https://github.com/sass/sass/spec/tree/main/js-api/compile.d.ts for
/// details.
JSPromise<JSCompileResult> compileStringAsync(String text,
    [AsyncCompileOptions? options_]) {
  var options = options_ ?? AsyncCompileOptions();

  return Future.sync(() async {
    var color = options.alertColor;
    var ascii = options.alertAscii;
    var logger = options.logger(Logger.stderr(color: color), ascii: ascii);
    try {
      var result = await compileStringToResultAsync(
        text,
        syntax: options.syntax,
        url: options.url,
        color: color,
        loadPaths: options.loadPaths?.toDart,
        quietDeps: options.quietDeps,
        style: options.outputStyle,
        verbose: options.verbose,
        charset: options.charset,
        sourceMap: options.sourceMap,
        logger: logger,
        importers: options.asyncImporters,
        importer: options.asyncImporter,
        functions: options.asyncFunctions,
        fatalDeprecations: options.fatalDeprecations(logger),
        silenceDeprecations: options.silenceDeprecations(logger),
        futureDeprecations: options.futureDeprecations(logger),
      );
      return result.toJS(
        includeSourceContents: options.sourceMapIncludeSources,
      );
    } on SassException catch (error, stackTrace) {
      throw JSSassException(error,
          color: color, ascii: ascii, trace: stackTrace);
    }
  }).toJS;
}
