// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';

import '../exception.dart';
import 'utils.dart';

@JS()
@anonymous
class _NodeException {
  external SassException get _dartException;
}

/// The constructor for Sass's JS API exception class.
var exceptionConstructor = () {
  // There's no way to define this in pure Dart, because the only way to create
  // a subclass of the JS `Error` type that sets its internal `[[ErrorData]]`
  // field is to call `super()` with the ES6 class syntax.
  var klass = jsEval(r'''
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
  ''') as Function;

  addGetters(klass, {
    'sassMessage': (_NodeException exception) =>
        exception._dartException.message,
    'sassStack': (_NodeException exception) =>
        exception._dartException.trace.toString(),
    'span': (_NodeException exception) => exception._dartException.span
  });

  return klass;
}();

/// Wraps [exception] with a Node API exception and throws it.
///
/// If [color] is `true`, the thrown exception uses colors in its
/// stringification.
Never throwNodeException(SassException exception, {required bool color}) {
  jsThrow(callConstructor(exceptionConstructor, [
    exception,
    exception.toString(color: color).replaceFirst('Error: ', '')
  ]) as _NodeException);
}
