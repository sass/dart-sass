// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../hybrid/value/number.dart';
import '../value.dart';

extension type JSSassLegacyNumber._(JSLegacyValue _) implements JSLegacyValue {
  /// The JS constructor for the `sass.types.Number` class.
  static final jsClass = JSClass<JSSassLegacyNumber>(
      (
        JSSassLegacyNumber self,
        num? value, [
        String? unit,
        UnsafeDartWrapper<SassNumber>? modernValue,
      ]) {
        // Either [modernValue] or [value] must be passed.
        self.modernValue = modernValue ?? _parseNumber(value!, unit).toJS;
      }.toJSCaptureThis,
      name: 'sass.types.Number')
    ..defineMethods({
      'getValue':
          ((JSSassLegacyNumber self) => self.toDart.value).toJSCaptureThis,
      'setValue': (JSSassLegacyNumber self, num value) {
        self.modernValue = SassNumber.withUnits(
          value,
          numeratorUnits: self.toDart.numeratorUnits,
          denominatorUnits: self.toDart.denominatorUnits,
        ).toJS;
      }.toJSCaptureThis,
      'getUnit': ((JSSassLegacyNumber self) =>
          self.toDart.numeratorUnits.join('*') +
          (self.toDart.denominatorUnits.isEmpty ? '' : '/') +
          self.toDart.denominatorUnits.join('*')).toJSCaptureThis,
      'setUnit': (JSSassLegacyNumber self, String unit) {
        self.modernValue = _parseNumber(self.toDart.value, unit).toJS;
      }.toJSCaptureThis,
    });

  @JS('dartValue')
  external UnsafeDartWrapper<SassNumber> modernValue;

  SassNumber get toDart => modernValue.toDart;
}

extension SassNumberToJSLegacy on SassNumber {
  JSSassLegacyNumber get toJSLegacy =>
      JSSassLegacyNumber.jsClass.construct(null, null, toJS);
}

/// Parses a [SassNumber] from [value] and [unit], using Node Sass's unit
/// format.
SassNumber _parseNumber(num value, String? unit) {
  if (unit == null || unit.isEmpty) return SassNumber(value);
  if (!unit.contains("*") && !unit.contains("/")) {
    return SassNumber(value, unit);
  }

  var invalidUnit = ArgumentError.value(unit, 'unit', 'is invalid.');

  var operands = unit.split('/');
  if (operands.length > 2) throw invalidUnit;

  var numerator = operands[0];
  var denominator = operands.length == 1 ? null : operands[1];

  var numeratorUnits = numerator.isEmpty ? <String>[] : numerator.split('*');
  if (numeratorUnits.any((unit) => unit.isEmpty)) throw invalidUnit;

  var denominatorUnits =
      denominator == null ? <String>[] : denominator.split('*');
  if (denominatorUnits.any((unit) => unit.isEmpty)) throw invalidUnit;

  return SassNumber.withUnits(
    value,
    numeratorUnits: numeratorUnits,
    denominatorUnits: denominatorUnits,
  );
}
