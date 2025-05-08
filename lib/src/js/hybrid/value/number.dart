// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

extension type JSSassNumber._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSNumber> jsClass = () {
    var jsClass = JSClass<JSNumber>('sass.SassNumber', (
    JSSassNumber self,
    num value, [
    JSAny? unitOrOptions,
  ]) {
    if (unitOrOptions.isA<JSString>()) {
      return SassNumber(value, (unitOrOptions as JSString).toDart);
    }

    var options = unitOrOptions as _ConstructorOptions?;
    return SassNumber.withUnits(
      value,
      numeratorUnits:
          options?.numeratorUnits?.toDartList<JSString>().cast<Value>(),
      denominatorUnits:
          options?.denominatorUnits?.toDartList<JSString>().cast<Value>(),
    ).toJS;
  }.toJS)..defineGetters({
    'value': ((JSSassNumber self) => self.toDart.value).toJS,
    'isInt': ((JSSassNumber self) => self.toDart.isInt).toJS,
    'asInt': ((JSSassNumber self) => self.toDart.asInt).toJS,
    'numeratorUnits': ((JSSassNumber self) => self.toDart.numeratorUnits.toJSImmutable).toJS,
    'denominatorUnits': ((JSSassNumber self) =>
        self.toDart.denominatorUnits.toJSImmutable).toJS,
    'hasUnits': ((JSSassNumber self) => self.toDart.hasUnits).toJS,
  })..defineMethods({
    'assertInt': ((JSSassNumber self, [String? name]) => self.toDart.assertInt(name)).toJS,
    'assertInRange': ((JSSassNumber self, num min, num max, [String? name]) =>
        self.toDart.valueInRange(min, max, name)).toJS,
    'assertNoUnits': ((JSSassNumber self, [String? name]) =>
        self.toDart..assertNoUnits(name)).toJS,
    'assertUnit': ((JSSassNumber self, String unit, [String? name]) =>
        self.toDart..assertUnit(unit, name)).toJS,
    'hasUnit': ((JSSassNumber self, String unit) => self.toDart.hasUnit(unit)).toJS,
    'compatibleWithUnit': ((JSSassNumber self, String unit) =>
        self.toDart.hasUnits && self.toDart.compatibleWithUnit(unit)).toJS,
    'convert': ((
      JSSassNumber self,
      JSObject numeratorUnits,
      JSObject denominatorUnits, [
      String? name,
    ]) =>
        self.toDart.convert(
          numeratorUnits.toDartList<JSString>().cast<String>(),
          denominatorUnits.toDartList<JSString>().cast<String>(),
          name,
        ).toJS).toJS,
    'convertToMatch': (
      JSSassNumber self,
      JSSassNumber other, [
      String? name,
      String? otherName,
    ]) =>
        self.toDart.convertToMatch(other.toDart, name, otherName).toJS,
    'convertValue': ((
      JSSassNumber self,
      JSObject numeratorUnits,
      JSObject denominatorUnits, [
      String? name,
    ]) =>
        self.toDart.convertValue(
          numeratorUnits.toDartList<JSString>().cast<String>(),
          denominatorUnits.toDartList<JSString>().cast<String>(),
          name,
        ).toJS).toJS,
    'convertValueToMatch': ((
      JSSassNumber self,
      JSSassNumber other, [
      String? name,
      String? otherName,
    ]) =>
        self.toDart.convertValueToMatch(other, name, otherName).toJS).toJS,
    'coerce': ((
      JSSassNumber self,
      JSObject numeratorUnits,
      JSObject denominatorUnits, [
      String? name,
    ]) =>
        self.toDart.coerce(
          numeratorUnits.toDartList<JSString>().cast<String>(),
          denominatorUnits.toDartList<JSString>().cast<String>(),
          name,
        ).toJS).toJS,
    'coerceToMatch': ((
      JSSassNumber self,
      JSSassNumber other, [
      String? name,
      String? otherName,
    ]) =>
        self.toDart.coerceToMatch(other, name.toDart, otherName).toJS).toJS,
    'coerceValue': ((
      JSSassNumber self,
      JSObject numeratorUnits,
      JSObject denominatorUnits, [
      String? name,
    ]) =>
        self.toDart.coerceValue(
          numeratorUnits.toDartList<JSString>().cast<String>(),
          denominatorUnits.toDartList<JSString>().cast<String>(),
          name,
        ).toJS).toJS,
    'coerceValueToMatch': ((
      JSSassNumber self,
      JSSassNumber other, [
      String? name,
      String? otherName,
    ]) =>
        self.toDart.coerceValueToMatch(other, name, otherName).toJS).toJS,
  });

  // Our concrete number types are actually subclasses of [SassNumber], so we
  // have to go up one in the superclass chain to inject [jsClass].
  SassNumber(0).toJS.constructor.superclass.injectSuperclass(jsClass);

  return jsClass;
}();

  SassNumber get toDart => this as SassNumber;
}

extension SassNumberToJS on SassNumber {
  JSSassNumber get toJS => this as JSSassNumber;
}

@anonymous
extension type _ConstructorOptions._(JSObject _) implements JSObject {
  external JSObject? get numeratorUnits;
  external JSObject? get denominatorUnits;
}
