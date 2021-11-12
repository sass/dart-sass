// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../../value.dart';
import '../../reflection.dart';

@JS()
class _NodeSassNumber {
  external SassNumber get dartValue;
  external set dartValue(SassNumber dartValue);
}

/// Creates a new `sass.types.Number` object wrapping [value].
Object newNodeSassNumber(SassNumber value) =>
    legacyNumberClass.construct([null, null, value]);

/// The JS constructor for the `sass.types.Number` class.
final JSClass legacyNumberClass = createJSClass('sass.types.Number',
    (_NodeSassNumber thisArg, num? value,
        [String? unit, SassNumber? dartValue]) {
  // Either [dartValue] or [value] must be passed.
  thisArg.dartValue = dartValue ?? _parseNumber(value!, unit);
})
  ..defineMethods({
    'getValue': (_NodeSassNumber thisArg) => thisArg.dartValue.value,
    'setValue': (_NodeSassNumber thisArg, num value) {
      thisArg.dartValue = SassNumber.withUnits(value,
          numeratorUnits: thisArg.dartValue.numeratorUnits,
          denominatorUnits: thisArg.dartValue.denominatorUnits);
    },
    'getUnit': (_NodeSassNumber thisArg) =>
        thisArg.dartValue.numeratorUnits.join('*') +
        (thisArg.dartValue.denominatorUnits.isEmpty ? '' : '/') +
        thisArg.dartValue.denominatorUnits.join('*'),
    'setUnit': (_NodeSassNumber thisArg, String unit) {
      thisArg.dartValue = _parseNumber(thisArg.dartValue.value, unit);
    }
  });

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

  return SassNumber.withUnits(value,
      numeratorUnits: numeratorUnits, denominatorUnits: denominatorUnits);
}
