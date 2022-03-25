// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:node_interop/node_interop.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import '../exception.dart';
import '../utils.dart';
import 'reflection.dart';
import 'utils.dart';

@JS()
@anonymous
class _NodeException extends JsError {
  // Fake constructor to silence the no_generative_constructor_in_superclass
  // error.
  external factory _NodeException();

  external SassException get _dartException;
}

/// Sass's JS API exception class.
final JSClass exceptionClass = () {
  // There's no way to define this in pure Dart, because the only way to create
  // a subclass of the JS `Error` type that sets its internal `[[ErrorData]]`
  // field is to call `super()` with the ES6 class syntax.
  var jsClass = jsEval(r'''
    return class Exception extends Error {
      constructor(dartException, message) {
        super(message);

        // Define this as non-enumerable so that it doesn't show up when the
        // exception hits the top level.
        Object.defineProperty(this, '_dartException', {
          value: dartException,
          enumerable: false
        });
      }

      toString() {
        return this.message;
      }
    }
  ''') as JSClass;
  jsClass.setName('sass.Exception');

  jsClass.defineGetters({
    'sassMessage': (_NodeException exception) =>
        exception._dartException.message,
    'sassStack': (_NodeException exception) =>
        exception._dartException.trace.toString(),
    'span': (_NodeException exception) => exception._dartException.span
  });

  return jsClass;
}();

/// Wraps [exception] with a Node API exception and throws it.
///
/// If [color] is `true`, the thrown exception uses colors in its
/// stringification.
///
/// If [ascii] is `false`, the thrown exception uses non-ASCII characters in its
/// stringification.
///
/// If [trace] is passed, it's used as the stack trace for the JS exception.
Never throwNodeException(SassException exception,
    {required bool color, required bool ascii, StackTrace? trace}) {
  var wasAscii = glyph.ascii;
  glyph.ascii = ascii;
  try {
    var jsException = exceptionClass.construct([
      exception,
      exception.toString(color: color).replaceFirst('Error: ', '')
    ]) as _NodeException;
    trace = getTrace(exception) ?? trace;
    if (trace != null) attachJsStack(jsException, trace);
    jsThrow(jsException);
  } finally {
    glyph.ascii = wasAscii;
  }
}
