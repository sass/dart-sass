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
  if (num2 > 0) return num1 % num2;
  if (num2 == 0) return double.nan;

  // Dart has different mod-negative semantics than Ruby, and thus than
  // Sass.
  var result = num1 % num2;
  return result == 0 ? 0 : result + num2;
}

/// Return square root of [number]
SassNumber sqrt(SassNumber number) {
  number.assertNoUnits();
  return SassNumber(math.sqrt(number.value));
}

/// Return [num1]^[num2]
SassNumber pow(SassNumber num1, SassNumber num2) {
  num1.assertNoUnits();
  num2.assertNoUnits();
  return SassNumber(math.pow(num1.value, num2.value));
}
