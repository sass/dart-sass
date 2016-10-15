// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../value.dart';

/// The maximum distance two Sass numbers are allowed to be from one another
/// before they're considered different.
const epsilon = 1 / (10 * SassNumber.precision);

/// Returns whether [number1] and [number2] are equal within [epsilon].
bool fuzzyEquals(num number1, num number2) =>
    (number1 - number2).abs() < epsilon;

/// Returns a hash code for [number] that matches [fuzzyEquals].
int fuzzyHashCode(num number) => (number % epsilon).hashCode;

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

/// Rounds [number] to the nearest integer.
///
/// This rounds up numbers that are [fuzzyEquals] to `X.5`.
int fuzzyRound(num number) {
  // If the number is within epsilon of X.5, round up (or down for negative
  // numbers).
  if (fuzzyLessThan(number % 1, 0.5)) return number.round();
  return number > 0 ? number.ceil() : number.floor();
}

/// Returns [number] if it's within [min] and [max], or `null` if it's not.
///
/// If [number] is [fuzzyEquals] to [min] or [max], it's clamped to the
/// appropriate value.
num fuzzyCheckRange(num number, num min, num max) {
  if (fuzzyEquals(number, min)) return min;
  if (fuzzyEquals(number, max)) return max;
  if (number > min && number < max) return number;
  return null;
}

/// Throws a [RangeError] if [number] isn't within [min] and [max].
///
/// If [number] is [fuzzyEquals] to [min] or [max], it's clamped to the
/// appropriate value. [name] is used in error reporting.
num fuzzyAssertRange(num number, num min, num max, [String name]) {
  var result = fuzzyCheckRange(number, min, max);
  if (result != null) return result;
  throw new RangeError.value(number, name, "must be between $min and $max.");
}
