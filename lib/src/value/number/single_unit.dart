// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import '../../util/number.dart';
import '../../utils.dart';
import '../../value.dart';
import '../external/value.dart' as ext;
import '../number.dart';

/// A specialized subclass of [SassNumber] for numbers that have exactly one
/// numerator unit.
@sealed
class SingleUnitSassNumber extends SassNumber {
  final String _unit;

  List<String> get numeratorUnits => UnmodifiableListView([_unit]);

  List<String> get denominatorUnits => const [];

  bool get hasUnits => true;

  SingleUnitSassNumber(num value, this._unit,
      [Tuple2<SassNumber, SassNumber> asSlash])
      : super.protected(value, asSlash);

  SassNumber withValue(num value) => SingleUnitSassNumber(value, _unit);

  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      SingleUnitSassNumber(value, _unit, Tuple2(numerator, denominator));

  bool hasUnit(String unit) => unit == _unit;

  bool compatibleWithUnit(String unit) => conversionFactor(_unit, unit) != null;

  SassNumber coerceToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      convertToMatch(other, name, otherName);

  num coerceValueToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      convertValueToMatch(other, name, otherName);

  SassNumber convertToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      (other is SingleUnitSassNumber ? _coerceToUnit(other._unit) : null) ??
      // Call this to generate a consistent error message.
      super.convertToMatch(other, name, otherName);

  num convertValueToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      (other is SingleUnitSassNumber
          ? _coerceValueToUnit(other._unit)
          : null) ??
      // Call this to generate a consistent error message.
      super.convertValueToMatch(other, name, otherName);

  SassNumber coerce(List<String> newNumerators, List<String> newDenominators,
          [String name]) =>
      (newNumerators.length == 1 && newDenominators.isEmpty
          ? _coerceToUnit(newNumerators[0])
          : null) ??
      // Call this to generate a consistent error message.
      super.coerce(newNumerators, newDenominators, name);

  num coerceValue(List<String> newNumerators, List<String> newDenominators,
          [String name]) =>
      (newNumerators.length == 1 && newDenominators.isEmpty
          ? _coerceValueToUnit(newNumerators[0])
          : null) ??
      // Call this to generate a consistent error message.
      super.coerceValue(newNumerators, newDenominators, name);

  num coerceValueToUnit(String unit, [String name]) =>
      _coerceValueToUnit(unit) ??
      // Call this to generate a consistent error message.
      super.coerceValueToUnit(unit, name);

  /// A shorthand for [coerce] with only one numerator unit, except that it
  /// returns `null` if coercion fails.
  SassNumber _coerceToUnit(String unit) {
    if (_unit == unit) return this;

    var factor = conversionFactor(unit, _unit);
    return factor == null ? null : SingleUnitSassNumber(value * factor, unit);
  }

  /// Like [coerceValueToUnit], except that it returns `null` if coercion fails.
  num _coerceValueToUnit(String unit) {
    var factor = conversionFactor(unit, _unit);
    return factor == null ? null : value * factor;
  }

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
      return null;
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

  int get hashCode => fuzzyHashCode(value * canonicalMultiplierForUnit(_unit));
}
