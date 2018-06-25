// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js';
import 'dart:js_util';
import 'dart:typed_data';

import 'package:js/js.dart';

import 'function.dart';

/// Sets the `toString()` function for [object] to [body].
///
/// Dart's JS interop doesn't currently let us set toString() for custom
/// classes, so we use this as a workaround.
void setToString(object, String body()) =>
    setProperty(object, 'toString', allowInterop(body));

/// Adds a `toString()` method to [klass] that forwards to Dart's `toString()`.
void forwardToString(Function klass) {
  setProperty(getProperty(klass, 'prototype'), 'toString',
      allowInteropCaptureThis((thisArg) => thisArg.toString()));
}

/// Throws [error] like JS would, without any Dart wrappers.
void jsThrow(error) => _jsThrow.call(error);

final _jsThrow = new JSFunction("error", "throw error;");

/// Returns whether or not [value] is the JS `undefined` value.
bool isUndefined(value) => _isUndefined.call(value) as bool;

final _isUndefined = new JSFunction("value", "return value === undefined;");

@JS("Error")
external Function get _JSError;

/// Returns whether [value] is a JS Error object.
bool isJSError(value) => instanceof(value, _JSError);

/// Invokes [function] with [thisArg] as `this`.
Object call2(JSFunction function, Object thisArg, Object arg1, Object arg2) =>
    function.apply(thisArg, [arg1, arg2]);

/// Invokes [function] with [thisArg] as `this`.
Object call3(JSFunction function, Object thisArg, Object arg1, Object arg2,
        Object arg3) =>
    function.apply(thisArg, [arg1, arg2, arg3]);

@JS("Object.keys")
external List<String> _keys(Object object);

/// Invokes [callback] for each key/value pair in [object].
void jsForEach(Object object, void callback(Object key, Object value)) {
  for (var key in _keys(object)) {
    callback(key, getProperty(object, key));
  }
}

/// Creates a JS class with the given [constructor] and [methods].
///
/// Both [constructor] and [methods] should take an initial `thisArg` parameter,
/// representing the object being constructed.
Function createClass(Function constructor, Map<String, Function> methods) {
  var klass = allowInteropCaptureThis(constructor);
  var prototype = getProperty(klass, 'prototype');
  methods.forEach((name, body) {
    setProperty(prototype, name, allowInteropCaptureThis(body));
  });
  return klass;
}

@JS("Object.getPrototypeOf")
external _getPrototypeOf(object);

@JS("Object.setPrototypeOf")
external void _setPrototypeOf(object, prototype);

@JS("Object.create")
external _create(prototype);

/// Injects [constructor] into the inheritance chain for [object]'s class.
void injectSuperclass(object, Function constructor) {
  var prototype = _getPrototypeOf(object);
  var parent = _getPrototypeOf(prototype);
  if (parent != null) {
    _setPrototypeOf(getProperty(constructor, 'prototype'), parent);
  }
  _setPrototypeOf(prototype, _create(getProperty(constructor, 'prototype')));
}

/// Returns whether [value] is truthy according to JavaScript.
bool isTruthy(Object value) => value != false && value != null;

@JS('Buffer.from')
external Uint8List _buffer(String text, String encoding);

/// Encodes [text] as a UTF-8 byte buffer.
///
/// We could do this using Dart's native UTF-8 support, but it's much less
/// efficient in Node.
Uint8List utf8Encode(String text) => _buffer(text, 'utf8');
