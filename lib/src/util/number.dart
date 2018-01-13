// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../value.dart';

/// The maximum distance two Sass numbers are allowed to be from one another
/// before they're considered different.
final epsilon = 1 / math.pow(10, SassNumber.precision);

/// `epsilon / 2`, cached since [math.pow] may not be computed at compile-time
/// and thus this probably won't be constant-folded.
final _epsilonOver2 = epsilon / 2;

/// Returns whether [number1] and [number2] are equal within [epsilon].
bool fuzzyEquals(num number1, num number2) =>
    (number1 - number2).abs() < epsilon;

/// Returns a hash code for [number] that matches [fuzzyEquals].
int fuzzyHashCode(num number) {
  var remainder = number % epsilon;
  var truncated = number - remainder;
  if (remainder >= _epsilonOver2) truncated += epsilon;
  return truncated.hashCode;
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
bool fuzzyIsInt(num number) {
  if (number is int) return true;

  // Check against 0.5 rather than 0.0 so that we catch numbers that are both
  // very slightly above an integer, and very slightly below.
  return fuzzyEquals((number - 0.5).abs() % 1, 0.5);
}

/// If [number] is an integer according to [fuzzyIsInt], returns it as an
/// [int].
///
/// Otherwise, returns `null`.
int fuzzyAsInt(num number) => fuzzyIsInt(number) ? number.round() : null;

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
