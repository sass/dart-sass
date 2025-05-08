// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../value.dart';
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

extension ValueToJS on Value {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<Value>> jsClass = (sassNull
      .toJS.constructor.superclass as JSClass<UnsafeDartWrapper<Value>>)
    ..setCustomInspect((self) => self.toDart.toString())
    ..defineGetters({
      'asList': (UnsafeDartWrapper<Value> self) =>
          self.toDart.asList.cast<UnsafeDartWrapper<Value>>().toJSImmutable,
      'hasBrackets': (UnsafeDartWrapper<Value> self) =>
          self.toDart.hasBrackets.toJS,
      'isTruthy': (UnsafeDartWrapper<Value> self) => self.toDart.isTruthy.toJS,
      'realNull': (UnsafeDartWrapper<Value> self) => self.toDart.realNull?.toJS,
      'separator': (UnsafeDartWrapper<Value> self) =>
          self.toDart.separator.separator?.toJS,
    })
    ..defineMethods({
      'sassIndexToListIndex': ((UnsafeDartWrapper<Value> self,
                  UnsafeDartWrapper<Value> sassIndex, [String? name]) =>
              self.toDart.sassIndexToListIndex(sassIndex.toDart, name))
          .toJSCaptureThis,
      'get': ((UnsafeDartWrapper<Value> self, num index) =>
          index < 1 && index >= -1 ? self : undefined).toJSCaptureThis,
      'assertBoolean': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertBoolean(name).toJS).toJSCaptureThis,
      'assertCalculation': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertCalculation(name).toJS).toJSCaptureThis,
      'assertColor': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertColor(name).toJS).toJSCaptureThis,
      'assertFunction': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertFunction(name).toJS).toJSCaptureThis,
      'assertMap': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertMap(name).toJS).toJSCaptureThis,
      'assertMixin': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertMixin(name).toJS).toJSCaptureThis,
      'assertNumber': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertNumber(name).toJS).toJSCaptureThis,
      'assertString': ((UnsafeDartWrapper<Value> self, [String? name]) =>
          self.toDart.assertString(name).toJS).toJSCaptureThis,
      'tryMap': ((UnsafeDartWrapper<Value> self) => self.toDart.tryMap()?.toJS)
          .toJSCaptureThis,
      'equals': ((UnsafeDartWrapper<Value> self, JSAny? other) => switch (
              other.asClassOrNull(jsClass)) {
            var value? => self.toDart == value.toDart,
            _ => null
          }).toJSCaptureThis,
      // For unclear reasons, the `immutable` package sometimes passes an extra
      // argument to `hashCode()`.
      'hashCode': ((UnsafeDartWrapper<Value> self, [JSAny? _]) =>
          self.toDart.hashCode).toJSCaptureThis,
      'toString': ((UnsafeDartWrapper<Value> self) => self.toDart.toString())
          .toJSCaptureThis,
    });

  UnsafeDartWrapper<Value> get toJS => toUnsafeWrapper;
}
