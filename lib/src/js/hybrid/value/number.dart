// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../../immutable.dart';

extension SassNumberToJS on SassNumber {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassNumber>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassNumber>>((
      num value, [
      JSAny? unitOrOptions,
    ]) {
      if (unitOrOptions.isA<JSString>()) {
        return SassNumber(value, (unitOrOptions as JSString).toDart).toJS;
      }

      var options = unitOrOptions as _ConstructorOptions?;
      return SassNumber.withUnits(
        value,
        numeratorUnits:
            options?.numeratorUnits?.toDartList<JSString>().cast<String>(),
        denominatorUnits:
            options?.denominatorUnits?.toDartList<JSString>().cast<String>(),
      ).toJS;
    }.toJS)
      ..defineGetters({
        'value': (UnsafeDartWrapper<SassNumber> self) => self.toDart.value.toJS,
        'isInt': (UnsafeDartWrapper<SassNumber> self) => self.toDart.isInt.toJS,
        'asInt': (UnsafeDartWrapper<SassNumber> self) =>
            self.toDart.asInt?.toJS,
        'numeratorUnits': (UnsafeDartWrapper<SassNumber> self) =>
            self.toDart.numeratorUnits.toJSImmutable,
        'denominatorUnits': (UnsafeDartWrapper<SassNumber> self) =>
            self.toDart.denominatorUnits.toJSImmutable,
        'hasUnits': (UnsafeDartWrapper<SassNumber> self) =>
            self.toDart.hasUnits.toJS,
      })
      ..defineMethods({
        'assertInt': ((UnsafeDartWrapper<SassNumber> self, [String? name]) =>
            self.toDart.assertInt(name)).toJSCaptureThis,
        'assertInRange': ((UnsafeDartWrapper<SassNumber> self, num min, num max,
                [String? name]) =>
            self.toDart.valueInRange(min, max, name)).toJSCaptureThis,
        'assertNoUnits': ((UnsafeDartWrapper<SassNumber> self,
                [String? name]) =>
            (self.toDart..assertNoUnits(name)).toJS).toJSCaptureThis,
        'assertUnit': ((UnsafeDartWrapper<SassNumber> self, String unit,
                [String? name]) =>
            (self.toDart..assertUnit(unit, name)).toJS).toJSCaptureThis,
        'hasUnit': ((UnsafeDartWrapper<SassNumber> self, String unit) =>
            self.toDart.hasUnit(unit)).toJSCaptureThis,
        'compatibleWithUnit': ((UnsafeDartWrapper<SassNumber> self,
                    String unit) =>
                self.toDart.hasUnits && self.toDart.compatibleWithUnit(unit))
            .toJSCaptureThis,
        'convert': ((
          UnsafeDartWrapper<SassNumber> self,
          JSObject numeratorUnits,
          JSObject denominatorUnits, [
          String? name,
        ]) =>
            self.toDart
                .convert(
                  numeratorUnits.toDartList<JSString>().cast<String>(),
                  denominatorUnits.toDartList<JSString>().cast<String>(),
                  name,
                )
                .toJS).toJSCaptureThis,
        'convertToMatch': ((
          UnsafeDartWrapper<SassNumber> self,
          UnsafeDartWrapper<SassNumber> other, [
          String? name,
          String? otherName,
        ]) =>
                self.toDart.convertToMatch(other.toDart, name, otherName).toJS)
            .toJSCaptureThis,
        'convertValue': ((
          UnsafeDartWrapper<SassNumber> self,
          JSObject numeratorUnits,
          JSObject denominatorUnits, [
          String? name,
        ]) =>
            self.toDart
                .convertValue(
                  numeratorUnits.toDartList<JSString>().cast<String>(),
                  denominatorUnits.toDartList<JSString>().cast<String>(),
                  name,
                )
                .toJS).toJSCaptureThis,
        'convertValueToMatch': ((
          UnsafeDartWrapper<SassNumber> self,
          UnsafeDartWrapper<SassNumber> other, [
          String? name,
          String? otherName,
        ]) =>
            self.toDart
                .convertValueToMatch(other.toDart, name, otherName)
                .toJS).toJSCaptureThis,
        'coerce': ((
          UnsafeDartWrapper<SassNumber> self,
          JSObject numeratorUnits,
          JSObject denominatorUnits, [
          String? name,
        ]) =>
            self.toDart
                .coerce(
                  numeratorUnits.toDartList<JSString>().cast<String>(),
                  denominatorUnits.toDartList<JSString>().cast<String>(),
                  name,
                )
                .toJS).toJSCaptureThis,
        'coerceToMatch': ((
          UnsafeDartWrapper<SassNumber> self,
          UnsafeDartWrapper<SassNumber> other, [
          String? name,
          String? otherName,
        ]) =>
                self.toDart.coerceToMatch(other.toDart, name, otherName).toJS)
            .toJSCaptureThis,
        'coerceValue': ((
          UnsafeDartWrapper<SassNumber> self,
          JSObject numeratorUnits,
          JSObject denominatorUnits, [
          String? name,
        ]) =>
            self.toDart
                .coerceValue(
                  numeratorUnits.toDartList<JSString>().cast<String>(),
                  denominatorUnits.toDartList<JSString>().cast<String>(),
                  name,
                )
                .toJS).toJSCaptureThis,
        'coerceValueToMatch': ((
          UnsafeDartWrapper<SassNumber> self,
          UnsafeDartWrapper<SassNumber> other, [
          String? name,
          String? otherName,
        ]) =>
            self.toDart
                .coerceValueToMatch(other.toDart, name, otherName)
                .toJS).toJSCaptureThis,
      });

    // Our concrete number types are actually subclasses of [SassNumber], so we
    // have to go up one in the superclass chain to inject [jsClass].
    SassNumber(0).toJS.constructor.superclass!.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassNumber> get toJS => toUnsafeWrapper;
}

extension type _ConstructorOptions._(JSObject _) implements JSObject {
  external JSObject? get numeratorUnits;
  external JSObject? get denominatorUnits;
}
