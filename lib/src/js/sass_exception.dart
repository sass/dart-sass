// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import '../exception.dart';
import '../utils.dart';
import 'hybrid/file_span.dart';

@JS('Error')
external JSClass get _jsErrorClass;

/// The JS exception class thrown by Sass, which wraps the Dart exception
/// object.
extension type JSSassException._wrap(JSError _) implements JSError {
  static final JSClass<JSSassException> jsClass = () {
    // There's no way to define this in pure Dart, because the only way to create
    // a subclass of the JS `Error` type that sets its internal `[[ErrorData]]`
    // field is to call `super()` with the ES6 class syntax.
    var jsClass =
        JSClass<JSSassException>.extend('sass.Exception', _jsErrorClass,
            (thisThunk, superclassConstructor, args) {
      var dartException = (args[0] as UnsafeDartWrapper<SassException>).toDart;
      superclassConstructor.callAsFunction(null, args[1]);

      // Define this as non-enumerable so that it doesn't show up when the
      // exception hits the top level.
      thisThunk.thisArg.defineProperty(
          'dartException'.toJS,
          JSPropertyDescriptor.getValue(
              dartException.toExternalReference as JSAny,
              enumerable: false));
    });

    jsClass.defineMethod('toString'.toJS,
        ((JSSassException thisArg) => thisArg.message).toJSCaptureThis);

    jsClass.defineGetters({
      'sassMessage': (JSSassException exception) =>
          exception.dartException.toDart.message.toJS,
      'sassStack': (JSSassException exception) =>
          exception.dartException.toDart.trace.toString().toJS,
      'span': (JSSassException exception) =>
          exception.dartException.toDart.span.toJS,
    });

    return jsClass;
  }();

  /// Wraps [exception] with a [JSSassException].
  ///
  /// If [color] is `true`, the thrown exception uses colors in its
  /// stringification.
  ///
  /// If [ascii] is `false`, the thrown exception uses non-ASCII characters in its
  /// stringification.
  ///
  /// If [trace] is passed, it's used as the stack trace for the JS exception if
  /// there's not already one attached to the given exception.
  factory JSSassException(
    SassException exception, {
    required bool color,
    required bool ascii,
    String? trace,
  }) {
    var wasAscii = glyph.ascii;
    glyph.ascii = ascii;
    try {
      var jsException = jsClass.construct(
        exception.toUnsafeWrapper,
        exception.toString(color: color).replaceFirst('Error: ', '').toJS,
      );
      trace = getTrace(exception)?.toString() ?? trace;
      if (trace != null) jsException.stack = trace;
      return jsException;
    } finally {
      glyph.ascii = wasAscii;
    }
  }

  external UnsafeDartWrapper<SassException> get dartException;
}
