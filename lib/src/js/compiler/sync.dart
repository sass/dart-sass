// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../compile.dart';
import '../compile_options.dart';

extension type JSCompiler._(JSObject _) implements JSObject {
  /// A key used to distinguish official invocations of the constructor from
  /// those invoked by users.
  static final _constructionKey = JSSymbols.construct();

  static final JSClass<JSCompiler> jsClass = () {
    var jsClass = JSClass<JSCompiler>(
        (JSCompiler thisArg, [JSSymbol? constructionKey]) {
          if (constructionKey != JSCompiler._constructionKey) {
            JSError.throwLikeJS(
              JSError(
                ("Compiler can not be directly constructed. "
                    "Please use `sass.initCompiler()` instead."),
              ),
            );
          }

          thisArg.defineProperty('disposed'.toJS,
              JSPropertyDescriptor.getValue(false.toJS, writable: true));
        }.toJSCaptureThis,
        name: 'sass.Compiler');

    jsClass.defineMethods({
      'compile':
          (JSCompiler thisArg, String path, [SyncCompileOptions? options]) {
        thisArg._throwIfDisposed();
        return compile(path, options);
      }.toJSCaptureThis,
      'compileString': (
        JSCompiler thisArg,
        String source, [
        SyncCompileOptions? options,
      ]) {
        thisArg._throwIfDisposed();
        return compileString(source, options);
      }.toJSCaptureThis,
      'dispose': (JSCompiler thisArg) {
        thisArg.disposed = true;
      }.toJSCaptureThis,
    });

    return jsClass;
  }();

  factory JSCompiler() => JSCompiler.jsClass.construct(_constructionKey);

  /// A flag signifying whether the instance has been disposed.
  ///
  /// This is not enumerable from JS and is considered an implementation detail.
  external bool disposed;

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
}
