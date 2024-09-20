// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../callable.dart';
import '../deprecation.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../module/built_in.dart';
import '../util/number.dart';
import '../util/random.dart' show random;
import '../value.dart';

/// The global definitions of Sass math functions.
final global = UnmodifiableListView([
  _function("abs", r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    if (number.hasUnit("%")) {
      warnForDeprecation(
          "Passing percentage units to the global abs() function is "
          "deprecated.\n"
          "In the future, this will emit a CSS abs() function to be resolved "
          "by the browser.\n"
          "To preserve current behavior: math.abs($number)"
          "\n"
          "To emit a CSS abs() now: abs(#{$number})\n"
          "More info: https://sass-lang.com/d/abs-percent",
          Deprecation.absPercent);
    } else {
      warnForGlobalBuiltIn('math', 'abs');
    }
    return SassNumber.withUnits(number.value.abs(),
        numeratorUnits: number.numeratorUnits,
        denominatorUnits: number.denominatorUnits);
  }),
  _ceil.withDeprecationWarning('math'),
  _floor.withDeprecationWarning('math'),
  _max.withDeprecationWarning('math'),
  _min.withDeprecationWarning('math'),
  _percentage.withDeprecationWarning('math'),
  _randomFunction.withDeprecationWarning('math'),
  _round.withDeprecationWarning('math'),
  _unit.withDeprecationWarning('math'),
  _compatible.withDeprecationWarning('math').withName("comparable"),
  _isUnitless.withDeprecationWarning('math').withName("unitless"),
]);

/// The Sass math module.
final module = BuiltInModule("math", functions: <Callable>[
  _numberFunction("abs", (value) => value.abs()),
  _acos, _asin, _atan, _atan2, _ceil, _clamp, _cos, _compatible, _floor, //
  _hypot, _isUnitless, _log, _max, _min, _percentage, _pow, _randomFunction,
  _round, _sin, _sqrt, _tan, _unit, _div
], variables: {
  "e": SassNumber(math.e),
  "pi": SassNumber(math.pi),
  "epsilon": SassNumber(2.220446049250313e-16),
  "max-safe-integer": SassNumber(9007199254740991),
  "min-safe-integer": SassNumber(-9007199254740991),
  "max-number": SassNumber(double.maxFinite),
  "min-number": SassNumber(double.minPositive),
});

///
/// Bounding functions
///

final _ceil = _numberFunction("ceil", (value) => value.ceil().toDouble());

final _clamp = _function("clamp", r"$min, $number, $max", (arguments) {
  var min = arguments[0].assertNumber("min");
  var number = arguments[1].assertNumber("number");
  var max = arguments[2].assertNumber("max");

  // Even though we don't use the resulting values, `convertValueToMatch`
  // generates more user-friendly exceptions than [greaterThanOrEquals] since it
  // has more context about parameter names.
  number.convertValueToMatch(min, "number", "min");
  max.convertValueToMatch(min, "max", "min");

  if (min.greaterThanOrEquals(max).isTruthy) return min;
  if (min.greaterThanOrEquals(number).isTruthy) return min;
  if (number.greaterThanOrEquals(max).isTruthy) return max;
  return number;
});

final _floor = _numberFunction("floor", (value) => value.floor().toDouble());

final _max = _function("max", r"$numbers...", (arguments) {
  SassNumber? max;
  for (var value in arguments[0].asList) {
    var number = value.assertNumber();
    if (max == null || max.lessThan(number).isTruthy) max = number;
  }
  if (max != null) return max;
  throw SassScriptException("At least one argument must be passed.");
});

final _min = _function("min", r"$numbers...", (arguments) {
  SassNumber? min;
  for (var value in arguments[0].asList) {
    var number = value.assertNumber();
    if (min == null || min.greaterThan(number).isTruthy) min = number;
  }
  if (min != null) return min;
  throw SassScriptException("At least one argument must be passed.");
});

final _round = _numberFunction("round", (number) => number.round().toDouble());

///
/// Distance functions
///

final _hypot = _function("hypot", r"$numbers...", (arguments) {
  var numbers =
      arguments[0].asList.map((argument) => argument.assertNumber()).toList();
  if (numbers.isEmpty) {
    throw SassScriptException("At least one argument must be passed.");
  }

  var subtotal = 0.0;
  for (var i = 0; i < numbers.length; i++) {
    var number = numbers[i];
    var value = number.convertValueToMatch(
        numbers[0], "numbers[${i + 1}]", "numbers[1]");
    subtotal += math.pow(value, 2);
  }
  return SassNumber.withUnits(math.sqrt(subtotal),
      numeratorUnits: numbers[0].numeratorUnits,
      denominatorUnits: numbers[0].denominatorUnits);
});

///
/// Exponential functions
///

final _log = _function("log", r"$number, $base: null", (arguments) {
  var number = arguments[0].assertNumber("number");
  if (number.hasUnits) {
    throw SassScriptException("\$number: Expected $number to have no units.");
  } else if (arguments[1] == sassNull) {
    return SassNumber(math.log(number.value));
  }

  var base = arguments[1].assertNumber("base");
  if (base.hasUnits) {
    throw SassScriptException("\$base: Expected $base to have no units.");
  } else {
    return SassNumber(math.log(number.value) / math.log(base.value));
  }
});

final _pow = _function("pow", r"$base, $exponent", (arguments) {
  var base = arguments[0].assertNumber("base");
  var exponent = arguments[1].assertNumber("exponent");
  return pow(base, exponent);
});

final _sqrt = _singleArgumentMathFunc("sqrt", sqrt);

///
/// Trigonometric functions
///

final _acos = _singleArgumentMathFunc("acos", acos);

final _asin = _singleArgumentMathFunc("asin", asin);

final _atan = _singleArgumentMathFunc("atan", atan);

final _atan2 = _function("atan2", r"$y, $x", (arguments) {
  var y = arguments[0].assertNumber("y");
  var x = arguments[1].assertNumber("x");
  return atan2(y, x);
});

final _cos = _singleArgumentMathFunc("cos", cos);

final _sin = _singleArgumentMathFunc("sin", sin);

final _tan = _singleArgumentMathFunc("tan", tan);

///
/// Unit functions
///

final _compatible = _function("compatible", r"$number1, $number2", (arguments) {
  var number1 = arguments[0].assertNumber("number1");
  var number2 = arguments[1].assertNumber("number2");
  return SassBoolean(number1.isComparableTo(number2));
});

final _isUnitless = _function("is-unitless", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  return SassBoolean(!number.hasUnits);
});

final _unit = _function("unit", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  return SassString(number.unitString, quotes: true);
});

///
/// Other functions
///

final _percentage = _function("percentage", r"$number", (arguments) {
  var number = arguments[0].assertNumber("number");
  number.assertNoUnits("number");
  return SassNumber(number.value * 100, '%');
});

final _randomFunction = _function("random", r"$limit: null", (arguments) {
  if (arguments[0] == sassNull) return SassNumber(random.nextDouble());
  var limit = arguments[0].assertNumber("limit");

  if (limit.hasUnits) {
    warnForDeprecation(
        "math.random() will no longer ignore \$limit units ($limit) in a "
        "future release.\n"
        "\n"
        "Recommendation: "
        "math.random(math.div(\$limit, 1${limit.unitString})) * 1${limit.unitString}\n"
        "\n"
        "To preserve current behavior: "
        "math.random(math.div(\$limit, 1${limit.unitString}))\n"
        "\n"
        "More info: https://sass-lang.com/d/function-units",
        Deprecation.functionUnits);
  }

  var limitScalar = limit.assertInt("limit");
  if (limitScalar < 1) {
    throw SassScriptException("\$limit: Must be greater than 0, was $limit.");
  }
  return SassNumber(random.nextInt(limitScalar) + 1);
});

final _div = _function("div", r"$number1, $number2", (arguments) {
  var number1 = arguments[0];
  var number2 = arguments[1];

  if (number1 is! SassNumber || number2 is! SassNumber) {
    warn("math.div() will only support number arguments in a future release.\n"
        "Use list.slash() instead for a slash separator.");
  }

  return number1.dividedBy(number2);
});

///
/// Helpers
///

/// Returns a [Callable] named [name] that calls a single argument
/// math function.
BuiltInCallable _singleArgumentMathFunc(
    String name, SassNumber mathFunc(SassNumber value)) {
  return _function(name, r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    return mathFunc(number);
  });
}

/// Returns a [Callable] named [name] that transforms a number's value
/// using [transform] and preserves its units.
BuiltInCallable _numberFunction(String name, double transform(double value)) {
  return _function(name, r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    return SassNumber.withUnits(transform(number.value),
        numeratorUnits: number.numeratorUnits,
        denominatorUnits: number.denominatorUnits);
  });
}

/// Like [_function.function], but always sets the URL to `sass:math`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:math");
