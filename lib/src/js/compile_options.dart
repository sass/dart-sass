// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:web/web.dart';

import '../callable.dart';
import '../importer.dart';
import '../importer/js_to_dart/async.dart';
import '../importer/js_to_dart/async_file.dart';
import '../importer/js_to_dart/file.dart';
import '../importer/js_to_dart/sync.dart';
import '../importer/no_op.dart';
import '../io.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../value.dart';
import '../visitor/serialize.dart';
import 'hybrid/node_importer.dart';
import 'hybrid/value.dart';
import 'importer.dart';
import 'shared_options.dart';
import 'utils.dart';

/// The base class for both synchronous and asynchronous compile options.
extension type _CompileOptions._(JSObject _) implements SharedOptions {
  @JS('alertAscii')
  external bool? get _alertAscii;

  /// Whether to use only ASCII characters in errors and warnings.
  bool get alertAscii => _alertAscii ?? glyph.ascii;

  @JS('alertColor')
  external bool? get _alertColor;

  /// Whether to use terminal colors in errors and warnings.
  bool get alertColor => _alertColor ?? hasTerminal;

  external JSArray<JSString>? get loadPaths;

  @JS('style')
  external String? get _style;

  /// The [OutputStyle] set by these options.
  OutputStyle get outputStyle => switch (_style) {
        null || 'expanded' => OutputStyle.expanded,
        'compressed' => OutputStyle.compressed,
        var style =>
          JSError.throwLikeJS(JSError('Unknown output style "$style".')),
      };

  @JS('sourceMap')
  external bool? get _sourceMap;

  /// Whether to emit a source map.
  bool get sourceMap => _sourceMap ?? false;

  @JS('sourceMapIncludeSources')
  external bool? get _sourceMapIncludeSources;

  /// Whether to include the original Sass stylesheet source in the source maps,
  /// if they're generated.
  bool get sourceMapIncludeSources => _sourceMapIncludeSources ?? false;

  @JS('importers')
  external JSArray<JSAny?>? get _importers;

  @JS('functions')
  external JSRecord<JSFunction>? get _functions;

  // The following options are only set for string compilations.

  @JS('syntax')
  external String? get _syntax;

  /// The syntax to use to parse the entrypoint stylesheet.
  Syntax get syntax => parseSyntax(_syntax);

  /// The canonical URL of the entrypoint stylesheet.
  Uri? get url => _url?.toDart;

  @JS('url')
  external URL? get _url;

  @JS('importer')
  external JSImporter? get _importer;
}

extension type SyncCompileOptions._(JSObject _) implements _CompileOptions {
  /// Returns the synchronous entrypoint importer defined by these options.
  Importer? get importer =>
      _importer?.andThen((importer) => _parseImporter(importer)) ??
      (url == null ? NoOpImporter() : null);

  /// Returns the list of synchronous importers defined by these options.
  Iterable<Importer> get importers =>
      _importers?.toDart.map(_parseImporter) ?? const [];

  /// Returns the list of synchronous functions defined by these options.
  List<Callable> get functions {
    var functions = _functions;
    if (functions == null) return const [];

    var result = <Callable>[];
    for (var (signature, callback) in functions.pairs) {
      late Callable callable;
      callable = Callable.fromSignature(signature, (arguments) {
        var result = callback.callAsFunction(
            null, [for (var argument in arguments) argument.toJS].toJS);
        if (result case Value value) return _simplifyValue(value);
        if (result.isA<JSPromise>()) {
          throw 'Invalid return value for custom function '
              '"${callable.name}":\n'
              'Promises may only be returned for sass.compileAsync() and '
              'sass.compileStringAsync().';
        } else {
          throw 'Invalid return value for custom function '
              '"${callable.name}": $result is not a sass.Value.';
        }
      });
      result.add(callable);
    }
    return result;
  }

  /// Converts [importer] into a synchronous [Importer].
  Importer _parseImporter(JSAny? importer) {
    if (importer.asClassOrNull(NodePackageImporterToJS.jsClass)
        case var importer?) {
      return importer.toDart;
    } else if (importer == null) {
      JSError.throwLikeJS(JSError("Importers may not be null."));
    }

    importer as JSImporter;
    var canonicalize = importer.canonicalize;
    var load = importer.load;
    if (importer.findFileUrl case var findFileUrl?) {
      if (canonicalize != null || load != null) {
        JSError.throwLikeJS(
          JSError(
            "An importer may not have a findFileUrl method as well as "
            "canonicalize and load methods.",
          ),
        );
      } else {
        return JSToDartFileImporter(findFileUrl);
      }
    } else if (canonicalize == null || load == null) {
      JSError.throwLikeJS(
        JSError(
          "An importer must have either canonicalize and load methods, or a "
          "findFileUrl method.",
        ),
      );
    } else {
      return JSToDartImporter(
        canonicalize,
        load,
        importer.nonCanonicalSchemes,
      );
    }
  }

  factory SyncCompileOptions() => SyncCompileOptions._(JSObject());
}

extension type AsyncCompileOptions._(JSObject _) implements _CompileOptions {
  /// Returns the list of asynchronous importers defined by these options.
  Iterable<AsyncImporter> get asyncImporters =>
      _importers?.toDart.map(_parseAsyncImporter) ?? const [];

  /// Returns the list of asynchronous functions defined by these options.
  List<AsyncCallable> get asyncFunctions {
    var functions = _functions;
    if (functions == null) return const [];

    var result = <AsyncCallable>[];
    for (var (signature, callback) in functions.pairs) {
      late AsyncCallable callable;
      callable = AsyncCallable.fromSignature(signature, (arguments) async {
        var result = callback.callAsFunction(
            null, [for (var argument in arguments) argument.toJS].toJS);
        if (result.isA<JSPromise>()) {
          result = await (result as JSPromise).toDart;
        }
        if (result case Value value) return _simplifyValue(value);
        throw 'Invalid return value for custom function '
            '"${callable.name}": $result is not a sass.Value.';
      });
      result.add(callable);
    }
    return result;
  }

  /// Returns the synchronous entrypoint importer defined by these options.
  AsyncImporter? get asyncImporter =>
      _importer?.andThen((importer) => _parseAsyncImporter(importer)) ??
      (url == null ? NoOpImporter() : null);

  /// Converts [importer] into an [AsyncImporter] that can be used with
  /// [compileAsync] or [compileStringAsync].
  AsyncImporter _parseAsyncImporter(JSAny? importer) {
    if (importer.asClassOrNull(NodePackageImporterToJS.jsClass)
        case var importer?) {
      return importer.toDart;
    } else if (importer == null) {
      JSError.throwLikeJS(JSError("Importers may not be null."));
    }

    importer as JSImporter;
    var canonicalize = importer.canonicalize;
    var load = importer.load;
    if (importer.findFileUrl case var findFileUrl?) {
      if (canonicalize != null || load != null) {
        JSError.throwLikeJS(
          JSError(
            "An importer may not have a findFileUrl method as well as "
            "canonicalize and load methods.",
          ),
        );
      } else {
        return JSToDartAsyncFileImporter(findFileUrl);
      }
    } else if (canonicalize == null || load == null) {
      JSError.throwLikeJS(
        JSError(
          "An importer must have either canonicalize and load methods, or a "
          "findFileUrl method.",
        ),
      );
    } else {
      return JSToDartAsyncImporter(
        canonicalize,
        load,
        importer.nonCanonicalSchemes,
      );
    }
  }

  factory AsyncCompileOptions() => AsyncCompileOptions._(JSObject());
}

/// Implements the simplification algorithm for custom function return `Value`s.
/// See https://github.com/sass/sass/blob/main/spec/types/calculation.md#simplifying-a-calculationvalue
Value _simplifyValue(Value value) => switch (value) {
      SassCalculation() => switch ((
          // Match against...
          value.name, // ...the calculation name
          value.arguments // ...and simplified arguments
              .map(_simplifyCalcArg)
              .toList(),
        )) {
          ('calc', [var first]) => first as Value,
          ('calc', _) =>
            throw ArgumentError('calc() requires exactly one argument.'),
          ('clamp', [var min, var value, var max]) => SassCalculation.clamp(
              min,
              value,
              max,
            ),
          ('clamp', _) =>
            throw ArgumentError('clamp() requires exactly 3 arguments.'),
          ('min', var args) => SassCalculation.min(args),
          ('max', var args) => SassCalculation.max(args),
          (var name, _) => throw ArgumentError(
              '"$name" is not a recognized calculation type.'),
        },
      _ => value,
    };

/// Handles simplifying calculation arguments, which are not guaranteed to be
/// Value instances.
Object _simplifyCalcArg(Object value) => switch (value) {
      SassCalculation() => _simplifyValue(value),
      CalculationOperation() => SassCalculation.operate(
          value.operator,
          _simplifyCalcArg(value.left),
          _simplifyCalcArg(value.right),
        ),
      _ => value,
    };
