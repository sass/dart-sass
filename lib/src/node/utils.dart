// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js';
import 'dart:js_util';
import 'dart:typed_data';

import 'package:node_interop/js.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import '../syntax.dart';
import 'array.dart';
import 'function.dart';
import 'url.dart';

/// Sets the `toString()` function for [object] to [body].
///
/// Dart's JS interop doesn't currently let us set toString() for custom
/// classes, so we use this as a workaround.
void setToString(Object object, String body()) =>
    setProperty(object, 'toString', allowInterop(body));

/// Adds a `toString()` method to [klass] that forwards to Dart's `toString()`.
void forwardToString(Function klass) {
  setProperty(getProperty(klass, 'prototype') as Object, 'toString',
      allowInteropCaptureThis((Object thisArg) => thisArg.toString()));
}

/// Throws [error] like JS would, without any Dart wrappers.
Never jsThrow(Object error) => _jsThrow.call(error) as Never;

final _jsThrow = JSFunction("error", "throw error;");

/// Returns whether or not [value] is the JS `undefined` value.
bool isUndefined(Object? value) => _isUndefined.call(value) as bool;

final _isUndefined = JSFunction("value", "return value === undefined;");

@JS("Error")
external Function get jsErrorConstructor;

/// Returns whether [value] is a JS Error object.
bool isJSError(Object value) => instanceof(value, jsErrorConstructor);

/// Invokes [function] with [thisArg] as `this`.
Object? call2(JSFunction function, Object thisArg, Object arg1, Object arg2) =>
    function.apply(thisArg, [arg1, arg2]);

/// Invokes [function] with [thisArg] as `this`.
Object? call3(JSFunction function, Object thisArg, Object arg1, Object arg2,
        Object arg3) =>
    function.apply(thisArg, [arg1, arg2, arg3]);

@JS("Object.keys")
external List<String> _keys(Object? object);

/// Invokes [callback] for each key/value pair in [object].
void jsForEach(Object object, void callback(Object key, Object? value)) {
  for (var key in _keys(object)) {
    callback(key, getProperty(object, key));
  }
}

/// Evaluates [js] in a function context.
///
/// If [js] includes a `return` statement, returns that result. Otherwise
/// returns `null`.
Object? jsEval(String js) => JSFunction('', js).call();

/// Creates a JS class with the given [name], [constructor] and [methods].
///
/// Both [constructor] and [methods] should take an initial `thisArg` parameter,
/// representing the object being constructed.
Function createClass(
    String name, Function constructor, Map<String, Function> methods) {
  var klass = allowInteropCaptureThis(constructor);
  _defineProperty(klass, 'name', _PropertyDescriptor(value: name));
  addMethods(klass, methods);
  return klass;
}

@JS("Object.getPrototypeOf")
external Function? _getPrototypeOf(Object object);

@JS("Object.setPrototypeOf")
external void _setPrototypeOf(Object object, Object prototype);

@JS("Object.defineProperty")
external void _defineProperty(
    Object object, String name, _PropertyDescriptor prototype);

@JS()
@anonymous
class _PropertyDescriptor {
  external Object get value;
  external Function get get;

  external factory _PropertyDescriptor({Object? value, Function? get});
}

@JS("Object.create")
external Object _create(Object prototype);

/// Sets the name of `object`'s class to `name`.
void setClassName(Object object, String name) {
  _defineProperty(getProperty(object, "constructor") as Object, "name",
      _PropertyDescriptor(value: name));
}

/// Injects [constructor] into the inheritance chain for [object]'s class.
void injectSuperclass(Object object, Function constructor) {
  var prototype = _getPrototypeOf(object)!;
  var parent = _getPrototypeOf(prototype);
  if (parent != null) {
    _setPrototypeOf(getProperty(constructor, 'prototype') as Object, parent);
  }
  _setPrototypeOf(
      prototype, _create(getProperty(constructor, 'prototype') as Object));
}

/// Adds [methods] to [constructor]'s prototype.
void addMethods(Function constructor, Map<String, Function> methods) {
  _addMethodsToPrototype(
      getProperty(constructor, 'prototype') as Object, methods);
}

/// Adds [getters] to [constructor]'s prototype.
void addGetters(Function constructor, Map<String, Function> getters) {
  _addGettersToPrototype(
      getProperty(constructor, 'prototype') as Object, getters);
}

/// Adds the JS [methods] to [object]'s prototype, so they're available in JS
/// for any instance of [dartObject]'s class.
void addMethodsToDartClass(Object dartObject, Map<String, Function> methods) {
  _addMethodsToPrototype(_getPrototypeOf(dartObject)!, methods);
}

/// Adds the JS [getters] to [object]'s prototype, so they're available in JS
/// for any instance of [dartObject]'s class.
void addGettersToDartClass(Object dartObject, Map<String, Function> getters) {
  _addGettersToPrototype(_getPrototypeOf(dartObject)!, getters);
}

/// Adds [methods] to [prototype].
void _addMethodsToPrototype(Object prototype, Map<String, Function> methods) {
  methods.forEach((name, body) {
    setProperty(prototype, name, allowInteropCaptureThis(body));
  });
}

/// Adds [getters] to [prototype].
void _addGettersToPrototype(Object prototype, Map<String, Function> getters) {
  getters.forEach((name, body) {
    _defineProperty(prototype, name,
        _PropertyDescriptor(get: allowInteropCaptureThis(body)));
  });
}

/// Returns whether [value] is truthy according to JavaScript.
bool isTruthy(Object? value) => value != false && value != null;

@JS('Promise')
external Function get _promiseClass;

/// Returns whether [object] is a `Promise`.
bool isPromise(Object? object) =>
    object != null && instanceof(object, _promiseClass);

@JS('URL')
external Function get _urlClass;

/// Returns whether [object] is a JavaScript `URL`.
bool isJSUrl(Object? object) => object != null && instanceof(object, _urlClass);

@JS('Buffer.from')
external Uint8List _buffer(String text, String encoding);

/// Encodes [text] as a UTF-8 byte buffer.
///
/// We could do this using Dart's native UTF-8 support, but it's much less
/// efficient in Node.
Uint8List utf8Encode(String text) => _buffer(text, 'utf8');

/// Converts a standard JS `URL` object to a Dart [Uri] object.
Uri jsToDartUrl(JSUrl url) => Uri.parse(url.toString());

/// Converts a Dart [Uri] object to a standard JS `URL` object.
JSUrl dartToJSUrl(Uri url) => JSUrl(url.toString());

/// Creates a JavaScript array containing [iterable].
///
/// While Dart arrays are notionally compatible with JS arrays, they still have
/// some non-enumerable properties that can cause problems (for example, they
/// don't compare as "equal" for Jest's matchers) so it's preferable to use this
/// when exposing them.
JSArray toJSArray(Iterable<Object?> iterable) {
  var array = JSArray();
  for (var element in iterable) {
    array.push(element);
  }
  return array;
}

/// Converts a syntax string to an instance of [Syntax].
Syntax parseSyntax(String? syntax) {
  if (syntax == null || syntax == 'scss') return Syntax.scss;
  if (syntax == 'indented') return Syntax.sass;
  if (syntax == 'css') return Syntax.css;
  jsThrow(JsError('Unknown syntax "$syntax".'));
}
