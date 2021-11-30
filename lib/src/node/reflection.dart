// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js';
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'utils.dart';
import 'utils.dart' as utils;

@JS("util.inspect.custom")
external Symbol get _inspectSymbol;

@JS("Object.getPrototypeOf")
external Object? _getPrototypeOf(Object object);

@JS("Object.setPrototypeOf")
external void _setPrototypeOf(Object object, Object prototype);

@JS("Object.create")
external Object _create(Object object);

/// The JavaScript constructor function that operates as a class.
///
/// We use this to perform reflection operations.
@JS()
@anonymous
class JSClass {
  external Object get prototype;
  external String get name;
}

/// Returns the reflected [JSClass] for a given object.
JSClass getJSClass(Object object) =>
    getProperty(object, "constructor") as JSClass;

/// Creates a JS class with the given [name] and [constructor].
///
/// The [constructor] should take an initial `self` parameter, representing the
/// object being constructed.
JSClass createJSClass(String name, Function constructor) =>
    allowInteropCaptureThisNamed(name, constructor) as JSClass;

/// Extension methods to make working reflectively with JS classes easier and
/// more readable.
extension JSClassExtension on JSClass {
  /// Constructs an instance of this class.
  Object construct(List<Object?> arguments) =>
      callConstructor(this, arguments) as Object;

  /// Sets a new name for this class.
  void setName(String name) {
    utils.defineGetter(this, 'name', value: name);
  }

  /// Returns this class's superclass.
  JSClass get superclass =>
      getProperty(_getPrototypeOf(prototype)!, 'constructor') as JSClass;

  /// Injects [superclass] as this class's immediate superclass, otherwise
  /// preserving the inheritance chain.
  void injectSuperclass(JSClass superclass) {
    _setPrototypeOf(superclass.prototype, this.superclass.prototype);
    _setPrototypeOf(prototype, _create(superclass.prototype));
  }

  /// Sets the custom inspect logic for this class to [body].
  void setCustomInspect(String inspect(Object self)) {
    setProperty(prototype, _inspectSymbol,
        allowInteropCaptureThis((Object self, _, __) => inspect(self)));
  }

  /// Defines a method with the given [name] and [body].
  ///
  /// The [body] should take an initial `self` parameter, representing the
  /// instance on which the method is being called.
  void defineMethod(String name, Function body) {
    setProperty(prototype, name, allowInteropCaptureThisNamed(name, body));
  }

  /// A shorthand for calling [defineMethod] multiple times.
  void defineMethods(Map<String, Function> methods) {
    methods.forEach(defineMethod);
  }

  /// Defines a getter with the given [name] and [body].
  ///
  /// The [body] should take an initial `self` parameter, representing the
  /// instance on which the method is being called.
  void defineGetter(String name, Function body) {
    utils.defineGetter(prototype, name, get: body);
  }

  /// A shorthand for calling [defineGetter] multiple times.
  void defineGetters(Map<String, Function> getters) {
    getters.forEach(defineGetter);
  }
}
