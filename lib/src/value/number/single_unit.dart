// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import '../../util/number.dart';
import '../../utils.dart';
import '../../util/nullable.dart';
import '../../value.dart';
import '../number.dart';

/// Sets of units that are known to be compatible with one another in the
/// browser.
///
/// These units are likewise known to be *incompatible* with units in other
/// sets in this list.
const _knownCompatibilities = [
  {
    "em", "ex", "ch", "rem", "vw", "vh", "vmin", "vmax", "cm", "mm", "q", //
    "in", "pt", "pc", "px"
  },
  {"deg", "grad", "rad", "turn"},
  {"s", "ms"},
  {"hz", "khz"},
  {"dpi", "dpcm", "dppx"}
];

/// A map from units to the other units they're known to be compatible with.
final _knownCompatibilitiesByUnit = {
  for (var set in _knownCompatibilities)
    for (var unit in set) unit: set
};

/// A specialized subclass of [SassNumber] for numbers that have exactly one
/// numerator unit.
///
/// {@category Value}
@sealed
class SingleUnitSassNumber extends SassNumber {
  final String _unit;

  List<String> get numeratorUnits => List.unmodifiable([_unit]);

  List<String> get denominatorUnits => const [];

  bool get hasUnits => true;

  SingleUnitSassNumber(num value, this._unit,
      [Tuple2<SassNumber, SassNumber>? asSlash])
      : super.protected(value, asSlash);

  SassNumber withValue(num value) => SingleUnitSassNumber(value, _unit);

  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      SingleUnitSassNumber(value, _unit, Tuple2(numerator, denominator));

  bool hasUnit(String unit) => unit == _unit;

  bool hasCompatibleUnits(SassNumber other) =>
      other is SingleUnitSassNumber && compatibleWithUnit(other._unit);

  @internal
  bool hasPossiblyCompatibleUnits(SassNumber other) {
    if (other is! SingleUnitSassNumber) return false;

    var knownCompatibilities = _knownCompatibilitiesByUnit[_unit.toLowerCase()];
    if (knownCompatibilities == null) return true;

    var otherUnit = other._unit.toLowerCase();
    return knownCompatibilities.contains(otherUnit) ||
        !_knownCompatibilitiesByUnit.containsKey(otherUnit);
  }

  bool compatibleWithUnit(String unit) => conversionFactor(_unit, unit) != null;

  SassNumber coerceToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      (other is SingleUnitSassNumber ? _coerceToUnit(other._unit) : null) ??
      // Call this to generate a consistent error message.
      super.coerceToMatch(other, name, otherName);

  num coerceValueToMatch(SassNumber other, [String? name, String? otherName]) =>
      (other is SingleUnitSassNumber
          ? _coerceValueToUnit(other._unit)
          : null) ??
      // Call this to generate a consistent error message.
      super.coerceValueToMatch(other, name, otherName);

  SassNumber convertToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      (other is SingleUnitSassNumber ? _coerceToUnit(other._unit) : null) ??
      // Call this to generate a consistent error message.
      super.convertToMatch(other, name, otherName);

  num convertValueToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      (other is SingleUnitSassNumber
          ? _coerceValueToUnit(other._unit)
          : null) ??
      // Call this to generate a consistent error message.
      super.convertValueToMatch(other, name, otherName);

  SassNumber coerce(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      (newNumerators.length == 1 && newDenominators.isEmpty
          ? _coerceToUnit(newNumerators[0])
          : null) ??
      // Call this to generate a consistent error message.
      super.coerce(newNumerators, newDenominators, name);

  num coerceValue(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      (newNumerators.length == 1 && newDenominators.isEmpty
          ? _coerceValueToUnit(newNumerators[0])
          : null) ??
      // Call this to generate a consistent error message.
      super.coerceValue(newNumerators, newDenominators, name);

  num coerceValueToUnit(String unit, [String? name]) =>
      _coerceValueToUnit(unit) ??
      // Call this to generate a consistent error message.
      super.coerceValueToUnit(unit, name);

  /// A shorthand for [coerce] with only one numerator unit, except that it
  /// returns `null` if coercion fails.
  SassNumber? _coerceToUnit(String unit) {
    if (_unit == unit) return this;
    return conversionFactor(unit, _unit)
        .andThen((factor) => SingleUnitSassNumber(value * factor, unit));
  }

  /// Like [coerceValueToUnit], except that it returns `null` if coercion fails.
  num? _coerceValueToUnit(String unit) =>
      conversionFactor(unit, _unit).andThen((factor) => value * factor);

  SassNumber multiplyUnits(
      num value, List<String> otherNumerators, List<String> otherDenominators) {
    var newNumerators = otherNumerators;
    var mutableOtherDenominators = otherDenominators.toList();
    removeFirstWhere<String>(mutableOtherDenominators, (denominator) {
      var factor = conversionFactor(denominator, _unit);
      if (factor == null) return false;
      value *= factor;
      return true;
    }, orElse: () {
      newNumerators = [_unit, ...newNumerators];
    });

    return SassNumber.withUnits(value,
        numeratorUnits: newNumerators,
        denominatorUnits: mutableOtherDenominators);
  }

  Value unaryMinus() => SingleUnitSassNumber(-value, _unit);

  bool operator ==(Object other) {
    if (other is SingleUnitSassNumber) {
      var factor = conversionFactor(other._unit, _unit);
      return factor != null && fuzzyEquals(value * factor, other.value);
    } else {
      return false;
    }
  }

  int get hashCode =>
      hashCache ??= fuzzyHashCode(value * canonicalMultiplierForUnit(_unit));
}
