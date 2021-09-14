// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import '../../util/number.dart';
import '../../value.dart';
import '../number.dart';

/// A specialized subclass of [SassNumber] for numbers that have no units.
///
/// {@category Value}
@sealed
class UnitlessSassNumber extends SassNumber {
  List<String> get numeratorUnits => const [];

  List<String> get denominatorUnits => const [];

  bool get hasUnits => false;

  UnitlessSassNumber(num value, [Tuple2<SassNumber, SassNumber>? asSlash])
      : super.protected(value, asSlash);

  SassNumber withValue(num value) => UnitlessSassNumber(value);

  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      UnitlessSassNumber(value, Tuple2(numerator, denominator));

  bool hasUnit(String unit) => false;

  bool hasCompatibleUnits(SassNumber other) => other is UnitlessSassNumber;

  @internal
  bool hasPossiblyCompatibleUnits(SassNumber other) =>
      other is UnitlessSassNumber;

  bool compatibleWithUnit(String unit) => true;

  SassNumber coerceToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      other.withValue(value);

  num coerceValueToMatch(SassNumber other, [String? name, String? otherName]) =>
      value;

  SassNumber convertToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      other.hasUnits
          // Call this to generate a consistent error message.
          ? super.convertToMatch(other, name, otherName)
          : this;

  num convertValueToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      other.hasUnits
          // Call this to generate a consistent error message.
          ? super.convertValueToMatch(other, name, otherName)
          : value;

  SassNumber coerce(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      SassNumber.withUnits(value,
          numeratorUnits: newNumerators, denominatorUnits: newDenominators);

  num coerceValue(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      value;

  num coerceValueToUnit(String unit, [String? name]) => value;

  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyGreaterThan(value, other.value));
    }
    return super.greaterThan(other);
  }

  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyGreaterThanOrEquals(value, other.value));
    }
    return super.greaterThanOrEquals(other);
  }

  SassBoolean lessThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyLessThan(value, other.value));
    }
    return super.lessThan(other);
  }

  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyLessThanOrEquals(value, other.value));
    }
    return super.lessThanOrEquals(other);
  }

  Value modulo(Value other) {
    if (other is SassNumber) {
      return other.withValue(moduloLikeSass(value, other.value));
    }
    return super.modulo(other);
  }

  Value plus(Value other) {
    if (other is SassNumber) {
      return other.withValue(value + other.value);
    }
    return super.plus(other);
  }

  Value minus(Value other) {
    if (other is SassNumber) {
      return other.withValue(value - other.value);
    }
    return super.minus(other);
  }

  Value times(Value other) {
    if (other is SassNumber) {
      return other.withValue(value * other.value);
    }
    return super.times(other);
  }

  Value dividedBy(Value other) {
    if (other is SassNumber) {
      return other.hasUnits
          ? SassNumber.withUnits(value / other.value,
              numeratorUnits: other.denominatorUnits,
              denominatorUnits: other.numeratorUnits)
          : UnitlessSassNumber(value / other.value);
    }
    return super.dividedBy(other);
  }

  Value unaryMinus() => UnitlessSassNumber(-value);

  bool operator ==(Object other) =>
      other is UnitlessSassNumber && fuzzyEquals(value, other.value);

  int get hashCode => fuzzyHashCode(value);
}
