// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop' as interop;
import 'dart:js_interop_unsafe';
import 'dart:js_util';
import 'dart:typed_data';

import 'package:node_interop/node.dart' hide module;
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import '../syntax.dart';
import '../utils.dart';
import '../util/map.dart';
import '../value.dart';
import 'array.dart';
import 'function.dart';
import 'module.dart';
import 'reflection.dart';
import 'url.dart';

/// Invokes [function] with [thisArg] as `this`.
Object? call2(JSFunction function, Object thisArg, Object arg1, Object arg2) =>
    function.apply(thisArg, [arg1, arg2]);

/// Invokes [function] with [thisArg] as `this`.
Object? call3(
  JSFunction function,
  Object thisArg,
  Object arg1,
  Object arg2,
  Object arg3,
) =>
    function.apply(thisArg, [arg1, arg2, arg3]);

@interop.JS("Object.keys")
external interop.JSArray<interop.JSString> _keys(interop.JSObject? object);

/// Invokes [callback] for each key/value pair in [object].
void jsForEach<V extends interop.JSAny?>(
    interop.JSObject object, void callback(String key, V value)) {
  var keys = _keys(object);
  for (var i = 0; i < keys.length; i++) {
    callback(keys[i].toDart, object.getProperty(key) as V);
  }
}

/// Evaluates [js] in a function context.
///
/// If [js] includes a `return` statement, returns that result. Otherwise
/// returns `null`.
Object? jsEval(String js) => JSFunction('', js).call();

/// Returns whether the [object] is a JS `string`.
bool isJsString(Object? object) => _jsTypeOf(object) == 'string';

/// Returns the [object]'s `typeof` according to the JS engine.
String _jsTypeOf(Object? object) =>
    JSFunction("value", "return typeof value").call(object) as String;

/// Returns `typeof value` if [value] is a native type, otherwise returns the
/// [value]'s JS class name.
String jsType(Object? value) {
  var typeOf = _jsTypeOf(value);
  return typeOf != 'object' ? typeOf : JSFunction('value', '''
    if (value && value.constructor && value.constructor.name) {
      return value.constructor.name;
    }
    return "object";
  ''').call(value) as String;
}

@JS("Object.defineProperty")
external void _defineProperty(
  Object object,
  String name,
  _PropertyDescriptor prototype,
);

@JS()
@anonymous
class _PropertyDescriptor {
  external Object get value;
  external Function get get;
  external bool get enumerable;

  external factory _PropertyDescriptor({
    Object? value,
    Function? get,
    bool? enumerable,
  });
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
            get: allowInteropCaptureThis(get),
            enumerable: false,
          ),
  );
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

@JS('Buffer.from')
external Uint8List _buffer(String text, String encoding);

/// Encodes [text] as a UTF-8 byte buffer.
///
/// We could do this using Dart's native UTF-8 support, but it's much less
/// efficient in Node.
Uint8List utf8Encode(String text) => _buffer(text, 'utf8');

/// Converts a JavaScript record into a map from property names to their values.
Map<String, Object?> objectToMap(Object object) {
  var map = <String, Object?>{};
  jsForEach(object, (key, value) => map[key] = value);
  return map;
}

@JS("Object")
external JSClass get _jsObjectClass;

/// Converts a JavaScript record into a map from property names to their values.
Object mapToObject(Map<String, Object?> map) {
  var result = callConstructor<Object>(_jsObjectClass, const []);
  for (var (key, value) in map.pairs) {
    setProperty(result, key, value);
  }
  return result;
}

/// Converts a JavaScript separator string into a [ListSeparator].
ListSeparator jsToDartSeparator(String? separator) => switch (separator) {
      ' ' => ListSeparator.space,
      ',' => ListSeparator.comma,
      '/' => ListSeparator.slash,
      null => ListSeparator.undecided,
      _ => JSError.throwLikeJS(JSError('Unknown separator "$separator".')),
    };

/// Converts a syntax string to an instance of [Syntax].
Syntax parseSyntax(String? syntax) => switch (syntax) {
      null || 'scss' => Syntax.scss,
      'indented' => Syntax.sass,
      'css' => Syntax.css,
      _ => JSError.throwLikeJS(JSError('Unknown syntax "$syntax".')),
    };

/// The path to the Node.js entrypoint, if one can be located.
String? get entrypointFilename {
  if (_requireMain?.filename case var filename?) {
    return filename;
  } else if (process.argv case [_, String path, ...]) {
    return module.createRequire(path).resolve(path);
  } else {
    return null;
  }
}

@JS("require.main")
external _RequireMain? get _requireMain;

@JS()
@anonymous
class _RequireMain {
  external String? get filename;
}
