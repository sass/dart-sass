// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../util/number.dart';
import '../../value.dart';

/// A specialized subclass of [SassNumber] for numbers that have no units.
///
/// {@category Value}
@sealed
class UnitlessSassNumber extends SassNumber {
  @override
  List<String> get numeratorUnits => const [];

  @override
  List<String> get denominatorUnits => const [];

  @override
  bool get hasUnits => false;

  @override
  bool get hasComplexUnits => false;

  UnitlessSassNumber(super.value, [super.asSlash]) : super.protected();

  @override
  SassNumber withValue(num value) => UnitlessSassNumber(value.toDouble());

  @override
  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      UnitlessSassNumber(value, (numerator, denominator));

  @override
  bool hasUnit(String unit) => false;

  @override
  bool hasCompatibleUnits(SassNumber other) => other is UnitlessSassNumber;

  @override
  @internal
  bool hasPossiblyCompatibleUnits(SassNumber other) =>
      other is UnitlessSassNumber;

  @override
  bool compatibleWithUnit(String unit) => true;

  @override
  SassNumber coerceToMatch(
    SassNumber other, [
    String? name,
    String? otherName,
  ]) =>
      other.withValue(value);

  @override
  double coerceValueToMatch(
    SassNumber other, [
    String? name,
    String? otherName,
  ]) =>
      value;

  @override
  SassNumber convertToMatch(
    SassNumber other, [
    String? name,
    String? otherName,
  ]) =>
      other.hasUnits
          // Call this to generate a consistent error message.
          ? super.convertToMatch(other, name, otherName)
          : this;

  @override
  double convertValueToMatch(
    SassNumber other, [
    String? name,
    String? otherName,
  ]) =>
      other.hasUnits
          // Call this to generate a consistent error message.
          ? super.convertValueToMatch(other, name, otherName)
          : value;

  @override
  SassNumber coerce(
    List<String> newNumerators,
    List<String> newDenominators, [
    String? name,
  ]) =>
      SassNumber.withUnits(
        value,
        numeratorUnits: newNumerators,
        denominatorUnits: newDenominators,
      );

  @override
  double coerceValue(
    List<String> newNumerators,
    List<String> newDenominators, [
    String? name,
  ]) =>
      value;

  @override
  double coerceValueToUnit(String unit, [String? name]) => value;

  @override
  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyGreaterThan(value, other.value));
    }
    return super.greaterThan(other);
  }

  @override
  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyGreaterThanOrEquals(value, other.value));
    }
    return super.greaterThanOrEquals(other);
  }

  @override
  SassBoolean lessThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyLessThan(value, other.value));
    }
    return super.lessThan(other);
  }

  @override
  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(fuzzyLessThanOrEquals(value, other.value));
    }
    return super.lessThanOrEquals(other);
  }

  @override
  SassNumber modulo(Value other) {
    if (other is SassNumber) {
      return other.withValue(moduloLikeSass(value, other.value));
    }
    return super.modulo(other);
  }

  @override
  Value plus(Value other) {
    if (other is SassNumber) {
      return other.withValue(value + other.value);
    }
    return super.plus(other);
  }

  @override
  Value minus(Value other) {
    if (other is SassNumber) {
      return other.withValue(value - other.value);
    }
    return super.minus(other);
  }

  @override
  Value times(Value other) {
    if (other is SassNumber) {
      return other.withValue(value * other.value);
    }
    return super.times(other);
  }

  @override
  Value dividedBy(Value other) {
    if (other is SassNumber) {
      return other.hasUnits
          ? SassNumber.withUnits(
              value / other.value,
              numeratorUnits: other.denominatorUnits,
              denominatorUnits: other.numeratorUnits,
            )
          : UnitlessSassNumber(value / other.value);
    }
    return super.dividedBy(other);
  }

  @override
  Value unaryMinus() => UnitlessSassNumber(-value);

  @override
  bool operator ==(Object other) =>
      other is UnitlessSassNumber && fuzzyEquals(value, other.value);

  @override
  int get hashCode => hashCache ??= fuzzyHashCode(value);
}
