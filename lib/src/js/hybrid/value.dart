// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../value.dart';
import '../../util/nullable.dart';
import '../extension/class.dart';
import '../immutable.dart';

export 'value/argument_list.dart';
export 'value/boolean.dart';
export 'value/calculation.dart';
export 'value/color.dart';
export 'value/function.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/mixin.dart';
export 'value/number.dart';
export 'value/string.dart';

extension type JSValue._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSValue> jsClass =
      Value.bogus.toJS.constructor.superclass
        ..setCustomInspect((self) => self.toDart.toString())
        ..defineGetters({
          'asList': ((JSValue self) =>
              self.toDart.asList.cast<JSValue>().toJSImmutable).toJS,
          'hasBrackets': ((JSValue self) => self.toDart.hasBrackets).toJS,
          'isTruthy': ((JSValue self) => self.toDart.isTruthy).toJS,
          'realNull': ((JSValue self) => self.toDart.realNull).toJS,
          'separator': ((JSValue self) => self.toDart.separator.separator).toJS,
        })
        ..defineMethods({
          'sassIndexToListIndex': ((JSValue self, JSValue sassIndex,
                  [String? name]) =>
              self.toDart.sassIndexToListIndex(sassIndex.toDart, name)).toJS,
          'get': ((JSValue self, num index) =>
              index < 1 && index >= -1 ? self : undefined).toJS,
          'assertBoolean': ((JSValue self, [String? name]) =>
              self.toDart.assertBoolean(name).toJS).toJS,
          'assertCalculation': ((JSValue self, [String? name]) =>
              self.toDart.assertCalculation(name).toJS).toJS,
          'assertColor': ((JSValue self, [String? name]) =>
              self.toDart.assertColor(name).toJS).toJS,
          'assertFunction': ((JSValue self, [String? name]) =>
              self.toDart.assertFunction(name).toJS).toJS,
          'assertMap': ((JSValue self, [String? name]) =>
              self.toDart.assertMap(name).toJS).toJS,
          'assertMixin': ((JSValue self, [String? name]) =>
              self.toDart.assertMixin(name).toJS).toJS,
          'assertNumber': ((JSValue self, [String? name]) =>
              self.toDart.assertNumber(name).toJS).toJS,
          'assertString': ((JSValue self, [String? name]) =>
              self.toDart.assertString(name).toJS).toJS,
          'tryMap': ((JSValue self) => self.toDart.tryMap().toJS).toJS,
          'equals': ((JSValue self, JSAny? other) => self.toDart == other).toJS,
          // For unclear reasons, the `immutable` package sometimes passes an extra
          // argument to `hashCode()`.
          'hashCode': ((JSValue self, [JSAny? _]) => self.toDart.hashCode).toJS,
          'toString': ((JSValue self) => self.toDart.toString()).toJS,
        });

  Value get toDart => this as Value;
}

extension ValueToJS on Value {
  JSValue get toJS => this as JSValue;
}
