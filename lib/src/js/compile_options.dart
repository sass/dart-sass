// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:web/web.dart';

import '../io.dart';
import 'importer.dart';
import 'logger.dart';
import 'record.dart';
import 'shared_options.dart';
import 'url.dart';
import 'utils.dart';

/// The base class for both synchronous and asynchronous compile options.
@anonymous
extension type _CompileOptions._(SharedOptions _) implements SharedOptions {
  @JS('alertAscii')
  external bool? get _alertAscii;

  /// Whether to use only ASCII characters in errors and warnings.
  bool get alertAscii => _alertAscii ?? glyph.ascii;

  @JS('alertColor')
  external bool? get _alertColor;

  /// Whether to use terminal colors in errors and warnings.
  bool get alertColor => _alertColor ?? hasTerminal;

  external JSArray<String>? get loadPaths;

  @JS('style')
  external String? get _style;

  /// The [OutputStyle] set by these options.
  OutputStyle get outputStyle => switch (_style) {
        null || 'expanded' => OutputStyle.expanded,
        'compressed' => OutputStyle.compressed,
        _ => JSError.throwLikeJS(JSError('Unknown output style "$style".')),
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
  external JSArray<JSFunction?>? get _importers;

  @JS('functions')
  external JSRecord<JSFunction>? get _functions;

  // The following options are only set for string compilations.

  @JS('syntax')
  external String? get _syntax;

  /// The syntax to use to parse the entrypoint stylesheet.
  Syntax get syntax => parseSyntax(_syntax);

  @JS('url')
  external URL? get url;

  /// The canonical URL of the entrypoint stylesheet.
  Uri? get url => url?.toDart;

  @JS('importer')
  external JSImporter? get _importer;
}

@anonymous
extension type SyncCompileOptions._(_CompileOptions _)
    implements _CompileOptions {
  /// Returns the synchronous entrypoint importer defined by these options.
  Importer? get importer =>
      importer?.andThen((importer) => _parseImporter(importer)) ??
      (options?.url == null ? NoOpImporter() : null);

  /// Returns the list of synchronous importers defined by these options.
  Iterable<Importer> get importers => _importers?.toDart.map(_parseImporter);

  /// Returns the list of synchronous functions defined by these options.
  List<Callable> get functions {
    if (_functions == null) return const [];

    var result = <Callable>[];
    for (var (signature, callback) in functions.pairs) {
      late Callable callable;
      callable = Callable.fromSignature(signature, (arguments) {
        var result = wrapJSExceptions(
          () => callback.callAsFunction(arguments.cast<JSAny?>().toJSCopy),
        );
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
    if (importer.instanceOf(JSNodePackageImporter.jsClass)) return importer;

    if (importer == null) {
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

  external SyncCompileOptions();
}

@anonymous
extension type AsyncCompileOptions._(_CompileOptions _)
    implements _CompileOptions {
  /// Returns the list of asynchronous importers defined by these options.
  Iterable<AsyncImporter> get asyncImporters =>
      _importers?.toDart.map(_parseAsyncImporter);

  /// Returns the list of asynchronous functions defined by these options.
  List<AsyncCallable> get asyncFunctions {
    if (_functions == null) return const [];

    var result = <AsyncCallable>[];
    for (var (signature, callback) in functions.pairs) {
      late AsyncCallable callable;
      callable = AsyncCallable.fromSignature(signature, (arguments) async {
        var result = wrapJSExceptions(
          () => callback.callAsFunction(arguments.cast<JSAny?>().toJSCopy),
        );
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
  Importer? get asyncImporter =>
      _importer?.andThen((importer) => _parseAsyncImporter(importer)) ??
      (url == null ? NoOpImporter() : null);

  /// Converts [importer] into an [AsyncImporter] that can be used with
  /// [compileAsync] or [compileStringAsync].
  AsyncImporter _parseAsyncImporter(JSAny? importer) {
    if (importer.instanceofClass(JSNodePackageImporter.jsClass))
      return importer;

    if (importer == null) {
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

  external AsyncCompileOptions();
}
