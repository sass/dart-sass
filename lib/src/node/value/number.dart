// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';

import '../../value.dart';
import '../utils.dart';

@JS()
class _NodeSassNumber {
  external SassNumber get dartValue;
  external set dartValue(SassNumber dartValue);
}

/// Creates a new `sass.types.Number` object wrapping [value].
Object newNodeSassNumber(SassNumber value) =>
    callConstructor(numberConstructor, [null, null, value]);

/// The JS constructor for the `sass.types.Number` class.
final Function numberConstructor = createClass(
    (_NodeSassNumber thisArg, num value, [String unit, SassNumber dartValue]) {
  thisArg.dartValue = dartValue ?? _parseNumber(value, unit);
}, {
  'getValue': (_NodeSassNumber thisArg) => thisArg.dartValue.value,
  'setValue': (_NodeSassNumber thisArg, num value) {
    thisArg.dartValue = new SassNumber.withUnits(value,
        numeratorUnits: thisArg.dartValue.numeratorUnits,
        denominatorUnits: thisArg.dartValue.denominatorUnits);
  },
  'getUnit': (_NodeSassNumber thisArg) =>
      thisArg.dartValue.numeratorUnits.join('*') +
      (thisArg.dartValue.denominatorUnits.isEmpty ? '' : '/') +
      thisArg.dartValue.denominatorUnits.join('*'),
  'setUnit': (_NodeSassNumber thisArg, String unit) {
    thisArg.dartValue = _parseNumber(thisArg.dartValue.value, unit);
  },
  'toString': (_NodeSassNumber thisArg) => thisArg.dartValue.toString()
});

/// Parses a [SassNumber] from [value] and [unit], using Node Sass's unit
/// format.
SassNumber _parseNumber(num value, String unit) {
  if (unit == null || unit.isEmpty) return new SassNumber(value);
  if (!unit.contains("*") && !unit.contains("/")) {
    return new SassNumber(value, unit);
  }

  var invalidUnit = new ArgumentError.value(unit, 'unit', 'is invalid.');

  var operands = unit.split('/');
  if (operands.length > 2) throw invalidUnit;

  var numerator = operands[0];
  var denominator = operands.length == 1 ? null : operands[1];

  var numeratorUnits = numerator.isEmpty ? <String>[] : numerator.split('*');
  if (numeratorUnits.any((unit) => unit.isEmpty)) throw invalidUnit;

  var denominatorUnits =
      denominator == null ? <String>[] : denominator.split('*');
  if (denominatorUnits.any((unit) => unit.isEmpty)) throw invalidUnit;

  return new SassNumber.withUnits(value,
      numeratorUnits: numeratorUnits, denominatorUnits: denominatorUnits);
}
