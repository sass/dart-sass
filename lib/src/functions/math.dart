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

/// A random number generator.
final _random = math.Random();

/// The global definitions of Sass math functions.
final global = UnmodifiableListView([
  _round, _ceil, _floor, _abs, _max, _min, _randomFunction, _unit, //
  _percentage,
  _isUnitless.withName("unitless"),
  _compatible.withName("comparable")
]);

/// The Sass math module.
final module = BuiltInModule("math", functions: [
  _round, _ceil, _floor, _abs, _max, _min, _randomFunction, _unit,
  _isUnitless, //
  _percentage, _compatible
]);

final _percentage = BuiltInCallable("percentage", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  number.assertNoUnits("number");
  return SassNumber(number.value * 100, '%');
});

final _round = _numberFunction("round", fuzzyRound);
final _ceil = _numberFunction("ceil", (value) => value.ceil());
final _floor = _numberFunction("floor", (value) => value.floor());
final _abs = _numberFunction("abs", (value) => value.abs());

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

final _randomFunction = BuiltInCallable("random", r"$limit: null", (arguments) {
  if (arguments[0] == sassNull) return SassNumber(_random.nextDouble());
  var limit = arguments[0].assertNumber("limit").assertInt("limit");
  if (limit < 1) {
    throw SassScriptException("\$limit: Must be greater than 0, was $limit.");
  }
  return SassNumber(_random.nextInt(limit) + 1);
});

final _unit = BuiltInCallable("unit", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  return SassString(number.unitString, quotes: true);
});

final _isUnitless = BuiltInCallable("is-unitless", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  return SassBoolean(!number.hasUnits);
});

final _compatible =
    BuiltInCallable("compatible", r"$number1, $number2", (arguments) {
  var number1 = arguments[0].assertNumber("number1");
  var number2 = arguments[1].assertNumber("number2");
  return SassBoolean(number1.isComparableTo(number2));
});

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
