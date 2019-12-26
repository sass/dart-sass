// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../callable.dart';
import '../exception.dart';
import '../module/built_in.dart';
import '../util/number.dart';
import '../value.dart';

/// The global definitions of Sass math functions.
final global = UnmodifiableListView([
  _abs, _ceil, _floor, _max, _min, _percentage, _randomFunction, _round,
  _unit, //
  _compatible.withName("comparable"),
  _isUnitless.withName("unitless"),
]);

/// The Sass math module.
final module = BuiltInModule("math", functions: [
  _abs, _ceil, _clamp, _compatible, _floor, _hypot, _isUnitless, _max, _min, //
  _percentage, _randomFunction, _round, _unit,
]);

/// Returns a [Callable] named [name] that transforms a number's value
/// using [transform] and preserves its units.
BuiltInCallable _numberFunction(String name, num transform(num value)) {
  return BuiltInCallable(name, r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    return SassNumber.withUnits(transform(number.value),
        numeratorUnits: number.numeratorUnits,
        denominatorUnits: number.denominatorUnits);
  });
}

///
/// Bounding functions
///

final _ceil = _numberFunction("ceil", (value) => value.ceil());

final _clamp = BuiltInCallable("clamp", r"$min, $number, $max", (arguments) {
  var min = arguments[0].assertNumber("min");
  var number = arguments[1].assertNumber("number");
  var max = arguments[2].assertNumber("max");

  if (min.hasUnits == number.hasUnits && number.hasUnits == max.hasUnits) {
    if (min.greaterThanOrEquals(max).isTruthy) return min;
    if (min.greaterThanOrEquals(number).isTruthy) return min;
    if (number.greaterThanOrEquals(max).isTruthy) return max;
    return number;
  }

  var arg2 = min.hasUnits != number.hasUnits ? number : max;
  var arg2Name = min.hasUnits != number.hasUnits ? "\$number" : "\$max";
  var unit1 = min.hasUnits ? "has unit ${min.unitString}" : "is unitless";
  var unit2 = arg2.hasUnits ? "has unit ${arg2.unitString}" : "is unitless";

  throw SassScriptException(
      "\$min $unit1 but $arg2Name $unit2. Arguments must all have units or all "
      "be unitless.");
});

final _floor = _numberFunction("floor", (value) => value.floor());

final _max = BuiltInCallable("max", r"$numbers...", (arguments) {
  SassNumber max;
  for (var value in arguments[0].asList) {
    var number = value.assertNumber();
    if (max == null || max.lessThan(number).isTruthy) max = number;
  }
  if (max != null) return max;
  throw SassScriptException("At least one argument must be passed.");
});

final _min = BuiltInCallable("min", r"$numbers...", (arguments) {
  SassNumber min;
  for (var value in arguments[0].asList) {
    var number = value.assertNumber();
    if (min == null || min.greaterThan(number).isTruthy) min = number;
  }
  if (min != null) return min;
  throw SassScriptException("At least one argument must be passed.");
});

final _round = _numberFunction("round", fuzzyRound);

///
/// Distance functions
///

final _abs = _numberFunction("abs", (value) => value.abs());

final _hypot = BuiltInCallable("hypot", r"$numbers...", (arguments) {
  var numbers =
      arguments[0].asList.map((argument) => argument.assertNumber()).toList();

  if (numbers.isEmpty) {
    throw SassScriptException("At least one argument must be passed.");
  }

  var numeratorUnits = numbers[0].numeratorUnits;
  var denominatorUnits = numbers[0].denominatorUnits;
  var subtotal = 0.0;

  for (var i = 0; i < numbers.length; i++) {
    var number = numbers[i];

    if (number.hasUnits != numbers[0].hasUnits) {
      var unit1 = numbers[0].hasUnits
          ? "has unit ${numbers[0].unitString}"
          : "is unitless";
      var unit2 =
          number.hasUnits ? "has unit ${number.unitString}" : "is unitless";
      throw SassScriptException(
          "Argument 1 $unit1 but argument ${i + 1} $unit2. Arguments must all "
          "have units or all be unitless.");
    }

    number = number.coerce(numeratorUnits, denominatorUnits);
    subtotal += math.pow(number.value, 2);
  }

  return SassNumber.withUnits(math.sqrt(subtotal),
      numeratorUnits: numeratorUnits, denominatorUnits: denominatorUnits);
});

///
/// Unit functions
///

final _compatible =
    BuiltInCallable("compatible", r"$number1, $number2", (arguments) {
  var number1 = arguments[0].assertNumber("number1");
  var number2 = arguments[1].assertNumber("number2");
  return SassBoolean(number1.isComparableTo(number2));
});

final _isUnitless = BuiltInCallable("is-unitless", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  return SassBoolean(!number.hasUnits);
});

final _unit = BuiltInCallable("unit", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  return SassString(number.unitString, quotes: true);
});

///
/// Other functions
///

final _percentage = BuiltInCallable("percentage", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  number.assertNoUnits("number");
  return SassNumber(number.value * 100, '%');
});

final _random = math.Random();

final _randomFunction = BuiltInCallable("random", r"$limit: null", (arguments) {
  if (arguments[0] == sassNull) return SassNumber(_random.nextDouble());
  var limit = arguments[0].assertNumber("limit").assertInt("limit");
  if (limit < 1) {
    throw SassScriptException("\$limit: Must be greater than 0, was $limit.");
  }
  return SassNumber(_random.nextInt(limit) + 1);
});
