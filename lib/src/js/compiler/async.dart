// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:async/async.dart';
import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../compile.dart';
import '../compile_options.dart';

extension type JSAsyncCompiler._(JSObject _) implements JSObject {
  /// A key used to distinguish official invocations of the constructor from
  /// those invoked by users.
  static final _constructionKey = JSSymbols.construct();

  static final JSClass<JSAsyncCompiler> jsClass = () {
    var jsClass = JSClass<JSAsyncCompiler>(
        (JSAsyncCompiler thisArg, [JSSymbol? constructionKey]) {
          if (constructionKey != JSAsyncCompiler._constructionKey) {
            JSError.throwLikeJS(
              JSError(
                ("AsyncCompiler can not be directly constructed. "
                    "Please use `sass.initAsyncCompiler()` instead."),
              ),
            );
          }

          thisArg.defineProperty('disposed'.toJS,
              JSPropertyDescriptor.getValue(false.toJS, writable: true));

          thisArg.defineProperty(
              'compilations'.toJS,
              JSPropertyDescriptor.getValue(
                  FutureGroup<void>().toExternalReference as JSAny));
        }.toJSCaptureThis,
        name: 'sass.AsyncCompiler');

    jsClass.defineMethods({
      'compileAsync': (
        JSAsyncCompiler thisArg,
        String path, [
        AsyncCompileOptions? options,
      ]) {
        thisArg._throwIfDisposed();
        var compilation = compileAsync(path, options);
        thisArg._addCompilation(compilation);
        return compilation;
      }.toJSCaptureThis,
      'compileStringAsync': (
        JSAsyncCompiler thisArg,
        String source, [
        AsyncCompileOptions? options,
      ]) {
        thisArg._throwIfDisposed();
        var compilation = compileStringAsync(source, options);
        thisArg._addCompilation(compilation);
        return compilation;
      }.toJSCaptureThis,
      'dispose': (JSAsyncCompiler thisArg) {
        thisArg.disposed = true;
        return Future.sync(() async {
          var comps = thisArg.compilations.toDartObject;
          comps.close();
          await comps.future;
        }).toJS;
      }.toJSCaptureThis,
    });

    return jsClass;
  }();

  factory JSAsyncCompiler() =>
      JSAsyncCompiler.jsClass.construct(_constructionKey);

  /// A flag signifying whether the instance has been disposed.
  ///
  /// This is not enumerable from JS and is considered an implementation detail.
  external bool disposed;

  /// A set of all compilations, tracked to ensure all compilations complete
  /// before async disposal resolves.
  external final ExternalDartReference<FutureGroup<void>> compilations;

  /// Checks if `dispose()` has been called on this instance, and throws an
  /// error if it has.
  ///
  /// This is an internal-only method that's used to verify that compilation
  /// methods are not called after disposal.
  void _throwIfDisposed() {
    if (disposed) {
      JSError.throwLikeJS(JSError('Compiler has already been disposed.'));
    }
  }

  /// Adds a compilation to the FutureGroup.
  void _addCompilation(JSPromise<JSAny?> compilation) {
    var comp = compilation.toDart;
    var wrappedComp = comp.catchError((err) {
      /// Ignore errors so the FutureGroup doesn't close when a compilation
      /// fails.
      return null;
    });
    compilations.toDartObject.add(wrappedComp);
  }
}
