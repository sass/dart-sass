// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../value.dart';

/// The power of ten to which to round Sass numbers to determine if they're
/// [fuzzy equal] to one another
///
/// [fuzzy-equal]: https://github.com/sass/sass/blob/main/spec/types/number.md#fuzzy-equality
///
/// This is also the minimum distance such that `a - b > _epsilon` implies that
/// `a` isn't [fuzzy-equal] to `b`. Note that the inverse implication is not
/// necessarily true! For example, if `a = 5.1e-11` and `b = 4.4e-11`, then
/// `a - b < 1e-11` but `a` fuzzy-equals 5e-11 and b fuzzy-equals 4e-11.
final _epsilon = math.pow(10, -SassNumber.precision - 1);

/// `1 / _epsilon`, cached since [math.pow] may not be computed at compile-time
/// and thus this probably won't be constant-folded.
final _inverseEpsilon = math.pow(10, SassNumber.precision + 1);

/// Returns whether [number1] and [number2] are equal up to the 11th decimal
/// digit.
bool fuzzyEquals(num number1, num number2) {
  if (number1 == number2) return true;
  return (number1 - number2).abs() <= _epsilon &&
      (number1 * _inverseEpsilon).round() ==
          (number2 * _inverseEpsilon).round();
}

/// Returns a hash code for [number] that matches [fuzzyEquals].
int fuzzyHashCode(double number) {
  if (!number.isFinite) return number.hashCode;
  return (number * _inverseEpsilon).round().hashCode;
}

/// Returns whether [number1] is less than [number2], and not [fuzzyEquals].
bool fuzzyLessThan(num number1, num number2) =>
    number1 < number2 && !fuzzyEquals(number1, number2);

/// Returns whether [number1] is less than [number2], or [fuzzyEquals].
bool fuzzyLessThanOrEquals(num number1, num number2) =>
    number1 < number2 || fuzzyEquals(number1, number2);

/// Returns whether [number1] is greater than [number2], and not [fuzzyEquals].
bool fuzzyGreaterThan(num number1, num number2) =>
    number1 > number2 && !fuzzyEquals(number1, number2);

/// Returns whether [number1] is greater than [number2], or [fuzzyEquals].
bool fuzzyGreaterThanOrEquals(num number1, num number2) =>
    number1 > number2 || fuzzyEquals(number1, number2);

/// Returns whether [number] is [fuzzyEquals] to an integer.
bool fuzzyIsInt(double number) {
  if (number.isInfinite || number.isNaN) return false;
  return fuzzyEquals(number, number.round());
}

/// If [number] is an integer according to [fuzzyIsInt], returns it as an
/// [int].
///
/// Otherwise, returns `null`.
int? fuzzyAsInt(double number) {
  if (number.isInfinite || number.isNaN) return null;
  var rounded = number.round();
  return fuzzyEquals(number, rounded) ? rounded : null;
}

/// Rounds [number] to the nearest integer.
///
/// This rounds up numbers that are [fuzzyEquals] to `X.5`.
int fuzzyRound(num number) {
  // If the number is within epsilon of X.5, round up (or down for negative
  // numbers).
  if (number > 0) {
    return fuzzyLessThan(number % 1, 0.5) ? number.floor() : number.ceil();
  } else {
    return fuzzyLessThanOrEquals(number % 1, 0.5)
        ? number.floor()
        : number.ceil();
  }
}

/// Returns [number] if it's within [min] and [max], or `null` if it's not.
///
/// If [number] is [fuzzyEquals] to [min] or [max], it's clamped to the
/// appropriate value.
double? fuzzyCheckRange(double number, num min, num max) {
  if (fuzzyEquals(number, min)) return min.toDouble();
  if (fuzzyEquals(number, max)) return max.toDouble();
  if (number > min && number < max) return number;
  return null;
}

/// Throws a [RangeError] if [number] isn't within [min] and [max].
///
/// If [number] is [fuzzyEquals] to [min] or [max], it's clamped to the
/// appropriate value. [name] is used in error reporting.
double fuzzyAssertRange(double number, int min, int max, [String? name]) {
  var result = fuzzyCheckRange(number, min, max);
  if (result != null) return result;
  throw RangeError.range(
      number, min, max, name, "must be between $min and $max");
}

/// Return [num1] modulo [num2], using Sass's [floored division] modulo
/// semantics, which it inherited from Ruby and which differ from Dart's.
///
/// [floored division]: https://en.wikipedia.org/wiki/Modulo_operation#Variants_of_the_definition
double moduloLikeSass(double num1, double num2) {
  if (num1.isInfinite) return double.nan;
  if (num2.isInfinite) {
    return num1.signIncludingZero == num2.sign ? num1 : double.nan;
  }

  if (num2 > 0) return num1 % num2;
  if (num2 == 0) return double.nan;

  // Dart has different mod-negative semantics than Ruby, and thus than
  // Sass.
  var result = num1 % num2;
  return result == 0 ? 0 : result + num2;
}

/// Returns the square root of [number].
SassNumber sqrt(SassNumber number) {
  number.assertNoUnits("number");
  return SassNumber(math.sqrt(number.value));
}

/// Returns the sine of [number].
SassNumber sin(SassNumber number) =>
    SassNumber(math.sin(number.coerceValueToUnit("rad", "number")));

/// Returns the cosine of [number].
SassNumber cos(SassNumber number) =>
    SassNumber(math.cos(number.coerceValueToUnit("rad", "number")));

/// Returns the tangent of [number].
SassNumber tan(SassNumber number) =>
    SassNumber(math.tan(number.coerceValueToUnit("rad", "number")));

/// Returns the arctangent of [number].
SassNumber atan(SassNumber number) {
  number.assertNoUnits("number");
  return _radiansToDegrees(math.atan(number.value));
}

/// Returns the arcsine of [number].
SassNumber asin(SassNumber number) {
  number.assertNoUnits("number");
  return _radiansToDegrees(math.asin(number.value));
}

/// Returns the arccosine of [number]
SassNumber acos(SassNumber number) {
  number.assertNoUnits("number");
  return _radiansToDegrees(math.acos(number.value));
}

/// Returns the absolute value of [number].
SassNumber abs(SassNumber number) =>
    SassNumber(number.value.abs()).coerceToMatch(number);

/// Returns the logarithm of [number] with respect to [base].
SassNumber log(SassNumber number, SassNumber? base) {
  if (base != null) {
    return SassNumber(math.log(number.value) / math.log(base.value));
  }
  return SassNumber(math.log(number.value));
}

/// Returns the value of [base] raised to the power of [exponent].
SassNumber pow(SassNumber base, SassNumber exponent) {
  base.assertNoUnits("base");
  exponent.assertNoUnits("exponent");
  return SassNumber(math.pow(base.value, exponent.value));
}

/// Returns the arctangent for [y] and [x].
SassNumber atan2(SassNumber y, SassNumber x) =>
    _radiansToDegrees(math.atan2(y.value, x.convertValueToMatch(y, 'x', 'y')));

/// Returns [radians] as a [SassNumber] with unit `deg`.
SassNumber _radiansToDegrees(double radians) =>
    SassNumber.withUnits(radians * (180 / math.pi), numeratorUnits: ['deg']);

/// Extension methods to get the sign of the double's numerical value,
/// including positive and negative zero.
extension DoubleWithSignedZero on double {
  double get signIncludingZero {
    if (identical(this, -0.0)) return -1.0;
    if (this == 0) return 1.0;
    return sign;
  }
}
