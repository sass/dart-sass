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
import '../utils.dart';
import '../value.dart';
import 'array.dart';
import 'function.dart';
import 'reflection.dart';
import 'url.dart';

/// Throws [error] like JS would, without any Dart wrappers.
Never jsThrow(Object error) => _jsThrow.call(error) as Never;

final _jsThrow = JSFunction("error", "throw error;");

/// Returns whether or not [value] is the JS `undefined` value.
bool isUndefined(Object? value) => _isUndefined.call(value) as bool;

final _isUndefined = JSFunction("value", "return value === undefined;");

@JS("Error")
external JSClass get jsErrorClass;

/// Returns whether [value] is a JS Error object.
bool isJSError(Object value) => instanceof(value, jsErrorClass);

/// Attaches [trace] to [error] as its stack trace.
void attachJsStack(JsError error, StackTrace trace) {
  // Stack traces in v8 contain the error message itself as well as the stack
  // information, so we trim that out if it exists so we don't double-print it.
  var traceString = trace.toString();
  var firstRealLine = traceString.indexOf('\n    at');
  if (firstRealLine != -1) {
    // +1 to account for the newline before the first line.
    traceString = traceString.substring(firstRealLine + 1);
  }

  setProperty(error, 'stack', "Error: ${error.message}\n$traceString");
}

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
void jsForEach(Object object, void callback(String key, Object? value)) {
  for (var key in _keys(object)) {
    callback(key, getProperty(object, key));
  }
}

/// Evaluates [js] in a function context.
///
/// If [js] includes a `return` statement, returns that result. Otherwise
/// returns `null`.
Object? jsEval(String js) => JSFunction('', js).call();

@JS("Object.defineProperty")
external void _defineProperty(
    Object object, String name, _PropertyDescriptor prototype);

@JS()
@anonymous
class _PropertyDescriptor {
  external Object get value;
  external Function get get;
  external bool get enumerable;

  external factory _PropertyDescriptor(
      {Object? value, Function? get, bool? enumerable});
}

/// Defines a JS getter on [object] named [name].
///
/// If [get] is passed, the getter invokes it with a `self` argument. Otherwise,
/// the getter just returns [value].
void defineGetter(Object object, String name, {Object? value, Function? get}) {
  _defineProperty(
      object,
      name,
      get == null
          ? _PropertyDescriptor(value: value, enumerable: false)
          : _PropertyDescriptor(
              get: allowInteropCaptureThis(get), enumerable: false));
}

/// Like [allowInterop], but gives the function a [name] so it's more ergonomic
/// when debugging.
T allowInteropNamed<T extends Function>(String name, T function) {
  function = allowInterop(function);
  defineGetter(function, 'name', value: name);
  _hideDartProperties(function);
  return function;
}

/// Like [allowInteropCaptureThis], but gives the function a [name] so it's more
/// ergonomic when debugging.
Function allowInteropCaptureThisNamed(String name, Function function) {
  function = allowInteropCaptureThis(function);
  defineGetter(function, 'name', value: name);
  _hideDartProperties(function);
  return function;
}

@JS("Object.getOwnPropertyNames")
external List<Object?> _getOwnPropertyNames(Object object);

/// Hide Dart-internal properties on [object].
///
/// Dart sometimes adds weird properties to objects that show up in
/// `utils.inspect()` or `console.log()`. This hides them by marking them as
/// non-enumerable.
void _hideDartProperties(Object object) {
  for (var name in _getOwnPropertyNames(object).cast<String>()) {
    if (name.startsWith('_')) {
      defineGetter(object, name, value: getProperty(object, name));
    }
  }
}

/// Returns whether [value] is truthy according to JavaScript.
bool isTruthy(Object? value) => value != false && value != null;

@JS('Promise')
external JSClass get _promiseClass;

/// Returns whether [object] is a `Promise`.
bool isPromise(Object? object) =>
    object != null && instanceof(object, _promiseClass);

/// Like [futureToPromise] from `node_interop`, but stores the stack trace for
/// errors using [throwWithTrace].
Promise futureToPromise(Future<Object?> future) => Promise(allowInterop(
        (void Function(Object?) resolve, void Function(Object?) reject) {
      future.then((result) => resolve(result),
          onError: (Object error, StackTrace stackTrace) {
        attachTrace(error, stackTrace);
        reject(error);
      });
    }));

@JS('URL')
external JSClass get _urlClass;

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

/// Converts a JavaScript record into a map from property names to their values.
Map<String, Object?> objectToMap(Object object) {
  var map = <String, Object?>{};
  jsForEach(object, (key, value) => map[key] = value);
  return map;
}

/// Converts a JavaScript separator string into a [ListSeparator].
ListSeparator jsToDartSeparator(String? separator) {
  switch (separator) {
    case ' ':
      return ListSeparator.space;
    case ',':
      return ListSeparator.comma;
    case '/':
      return ListSeparator.slash;
    case null:
      return ListSeparator.undecided;
    default:
      jsThrow(JsError('Unknown separator "$separator".'));
  }
}

/// Converts a syntax string to an instance of [Syntax].
Syntax parseSyntax(String? syntax) {
  if (syntax == null || syntax == 'scss') return Syntax.scss;
  if (syntax == 'indented') return Syntax.sass;
  if (syntax == 'css') return Syntax.css;
  jsThrow(JsError('Unknown syntax "$syntax".'));
}
