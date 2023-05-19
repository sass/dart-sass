// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../exception.dart';
import '../util/nullable.dart';
import '../util/number.dart' as number;
import '../utils.dart';
import '../value.dart';
import '../visitor/interface/value.dart';
import '../visitor/serialize.dart';

/// A SassScript calculation.
///
/// Although calculations can in principle have any name or any number of
/// arguments, this class only exposes the specific calculations that are
/// supported by the Sass spec. This ensures that all calculations that the user
/// works with are always fully simplified.
///
/// {@category Value}
@sealed
class SassCalculation extends Value {
  /// The calculation's name, such as `"calc"`.
  final String name;

  /// The calculation's arguments.
  ///
  /// Each argument is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], a [CalculationOperation], or a [CalculationInterpolation].
  final List<Object> arguments;

  /// @nodoc
  @internal
  bool get isSpecialNumber => true;

  /// Creates a new calculation with the given [name] and [arguments]
  /// that will not be simplified.
  @internal
  static SassCalculation unsimplified(
          String name, Iterable<Object> arguments) =>
      SassCalculation._(name, List.unmodifiable(arguments));

  /// Creates a `calc()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value calc(Object argument) {
    argument = _simplify(argument);
    if (argument is SassNumber) return argument;
    if (argument is SassCalculation) return argument;
    return SassCalculation._("calc", List.unmodifiable([argument]));
  }

  /// Creates a `min()` calculation with the given [arguments].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation]. It must be passed at least one argument.
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value min(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("min() must have at least one argument.");
    }

    SassNumber? minimum;
    for (var arg in args) {
      if (arg is! SassNumber ||
          (minimum != null && !minimum.isComparableTo(arg))) {
        minimum = null;
        break;
      } else if (minimum == null || minimum.greaterThan(arg).isTruthy) {
        minimum = arg;
      }
    }
    if (minimum != null) return minimum;

    _verifyCompatibleNumbers(args);
    return SassCalculation._("min", args);
  }

  /// Creates a `max()` calculation with the given [arguments].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation]. It must be passed at least one argument.
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value max(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("max() must have at least one argument.");
    }

    SassNumber? maximum;
    for (var arg in args) {
      if (arg is! SassNumber ||
          (maximum != null && !maximum.isComparableTo(arg))) {
        maximum = null;
        break;
      } else if (maximum == null || maximum.lessThan(arg).isTruthy) {
        maximum = arg;
      }
    }
    if (maximum != null) return maximum;

    _verifyCompatibleNumbers(args);
    return SassCalculation._("max", args);
  }

  /// Creates a `sqrt()` calculation with the given [argument].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation]. It must be passed at least one argument.
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  static Value sqrt(Object argument) {
    argument = _simplify(argument);
    if (argument is! SassNumber) {
      return SassCalculation._("sqrt", [argument]);
    }
    return number.sqrt(argument);
  }

  /// Creates a `clamp()` calculation with the given [min], [value], and [max].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than three arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value clamp(Object min, [Object? value, Object? max]) {
    if (value == null && max != null) {
      throw ArgumentError("If value is null, max must also be null.");
    }

    min = _simplify(min);
    value = value.andThen(_simplify);
    max = max.andThen(_simplify);

    if (min is SassNumber &&
        value is SassNumber &&
        max is SassNumber &&
        min.hasCompatibleUnits(value) &&
        min.hasCompatibleUnits(max)) {
      if (value.lessThanOrEquals(min).isTruthy) return min;
      if (value.greaterThanOrEquals(max).isTruthy) return max;
      return value;
    }

    var args = List<Object>.unmodifiable(
        [min, if (value != null) value, if (max != null) max]);
    _verifyCompatibleNumbers(args);
    _verifyLength(args, 3);
    return SassCalculation._("clamp", args);
  }

  /// Creates a `pow()` calculation with the given [min], [value], and [max].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation]. It throws an exception if it
  /// can determine that the calculation will definitely produce invalid CSS.
  ///
  /// This may be passed fewer than three arguments, but only if one of the
  /// arguments is an unquoted `var()` string.
  static Value pow(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    _verifyLength(args, 2);
    var num1 = args[0];
    var num2 = args[1];
    if (num1 is! SassNumber || num2 is! SassNumber) {
      return SassCalculation._("pow", [num1, num2]);
    }

    return number.pow(num1, num2);
  }

  /// Creates and simplifies a [CalculationOperation] with the given [operator],
  /// [left], and [right].
  ///
  /// This automatically simplifies the operation, so it may return a
  /// [SassNumber] rather than a [CalculationOperation].
  ///
  /// Each of [left] and [right] must be either a [SassNumber], a
  /// [SassCalculation], an unquoted [SassString], a [CalculationOperation], or
  /// a [CalculationInterpolation].
  static Object operate(
          CalculationOperator operator, Object left, Object right) =>
      operateInternal(operator, left, right, inMinMax: false, simplify: true);

  /// Like [operate], but with the internal-only [inMinMax] parameter.
  ///
  /// If [inMinMax] is `true`, this allows unitless numbers to be added and
  /// subtracted with numbers with units, for backwards-compatibility with the
  /// old global `min()` and `max()` functions.
  ///
  /// If [simplify] is `false`, no simplification will be done.
  @internal
  static Object operateInternal(
      CalculationOperator operator, Object left, Object right,
      {required bool inMinMax, required bool simplify}) {
    if (!simplify) {
      return CalculationOperation._(operator, left, right);
    }
    left = _simplify(left);
    right = _simplify(right);

    if (operator == CalculationOperator.plus ||
        operator == CalculationOperator.minus) {
      if (left is SassNumber &&
          right is SassNumber &&
          (inMinMax
              ? left.isComparableTo(right)
              : left.hasCompatibleUnits(right))) {
        return operator == CalculationOperator.plus
            ? left.plus(right)
            : left.minus(right);
      }

      _verifyCompatibleNumbers([left, right]);

      if (right is SassNumber && number.fuzzyLessThan(right.value, 0)) {
        right = right.times(SassNumber(-1));
        operator = operator == CalculationOperator.plus
            ? CalculationOperator.minus
            : CalculationOperator.plus;
      }

      return CalculationOperation._(operator, left, right);
    } else if (left is SassNumber && right is SassNumber) {
      return operator == CalculationOperator.times
          ? left.times(right)
          : left.dividedBy(right);
    } else {
      return CalculationOperation._(operator, left, right);
    }
  }

  /// An internal constructor that doesn't perform any validation or
  /// simplification.
  SassCalculation._(this.name, this.arguments);

  /// Returns an unmodifiable list of [args], with each argument simplified.
  static List<Object> _simplifyArguments(Iterable<Object> args) =>
      List.unmodifiable(args.map(_simplify));

  /// Simplifies a calculation argument.
  static Object _simplify(Object arg) {
    if (arg is SassNumber ||
        arg is CalculationInterpolation ||
        arg is CalculationOperation) {
      return arg;
    } else if (arg is SassString) {
      if (!arg.hasQuotes) return arg;
      throw SassScriptException(
          "Quoted string $arg can't be used in a calculation.");
    } else if (arg is SassCalculation) {
      return arg.name == 'calc' ? arg.arguments[0] : arg;
    } else if (arg is Value) {
      throw SassScriptException("Value $arg can't be used in a calculation.");
    } else {
      throw ArgumentError("Unexpected calculation argument $arg.");
    }
  }

  /// Verifies that all the numbers in [args] aren't known to be incompatible
  /// with one another, and that they don't have units that are too complex for
  /// calculations.
  static void _verifyCompatibleNumbers(List<Object> args) {
    // Note: this logic is largely duplicated in
    // _EvaluateVisitor._verifyCompatibleNumbers and most changes here should
    // also be reflected there.
    for (var arg in args) {
      if (arg is! SassNumber) continue;
      if (arg.numeratorUnits.length > 1 || arg.denominatorUnits.isNotEmpty) {
        throw SassScriptException(
            "Number $arg isn't compatible with CSS calculations.");
      }
    }

    for (var i = 0; i < args.length - 1; i++) {
      var number1 = args[i];
      if (number1 is! SassNumber) continue;

      for (var j = i + 1; j < args.length; j++) {
        var number2 = args[j];
        if (number2 is! SassNumber) continue;
        if (number1.hasPossiblyCompatibleUnits(number2)) continue;
        throw SassScriptException("$number1 and $number2 are incompatible.");
      }
    }
  }

  /// Throws a [SassScriptException] if [args] isn't [expectedLength] *and*
  /// doesn't contain either a [SassString] or a [CalculationInterpolation].
  static void _verifyLength(List<Object> args, int expectedLength) {
    if (args.length == expectedLength) return;
    if (args
        .any((arg) => arg is SassString || arg is CalculationInterpolation)) {
      return;
    }
    throw SassScriptException(
        "$expectedLength arguments required, but only ${args.length} "
        "${pluralize('was', args.length, plural: 'were')} passed.");
  }

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitCalculation(this);

  SassCalculation assertCalculation([String? name]) => this;

  /// @nodoc
  @internal
  Value plus(Value other) {
    if (other is SassString) return super.plus(other);
    throw SassScriptException('Undefined operation "$this + $other".');
  }

  /// @nodoc
  @internal
  Value minus(Value other) =>
      throw SassScriptException('Undefined operation "$this - $other".');

  /// @nodoc
  @internal
  Value unaryPlus() =>
      throw SassScriptException('Undefined operation "+$this".');

  /// @nodoc
  @internal
  Value unaryMinus() =>
      throw SassScriptException('Undefined operation "-$this".');

  bool operator ==(Object other) =>
      other is SassCalculation &&
      name == other.name &&
      listEquals(arguments, other.arguments);

  int get hashCode => name.hashCode ^ listHash(arguments);
}

/// A binary operation that can appear in a [SassCalculation].
///
/// {@category Value}
@sealed
class CalculationOperation {
  /// We use a getters to allow overriding the logic in the JS API
  /// implementation.

  /// The operator.
  CalculationOperator get operator => _operator;
  final CalculationOperator _operator;

  /// The left-hand operand.
  ///
  /// This is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], a [CalculationOperation], or a [CalculationInterpolation].
  Object get left => _left;
  final Object _left;

  /// The right-hand operand.
  ///
  /// This is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], a [CalculationOperation], or a [CalculationInterpolation].
  Object get right => _right;
  final Object _right;

  CalculationOperation._(this._operator, this._left, this._right);

  bool operator ==(Object other) =>
      other is CalculationOperation &&
      operator == other.operator &&
      left == other.left &&
      right == other.right;

  int get hashCode => operator.hashCode ^ left.hashCode ^ right.hashCode;

  String toString() {
    var parenthesized =
        serializeValue(SassCalculation._("", [this]), inspect: true);
    return parenthesized.substring(1, parenthesized.length - 1);
  }
}

/// An enumeration of possible operators for [CalculationOperation].
///
/// {@category Value}
enum CalculationOperator {
  /// The addition operator.
  plus('plus', '+', 1),

  /// The subtraction operator.
  minus('minus', '-', 1),

  /// The multiplication operator.
  times('times', '*', 2),

  /// The division operator.
  dividedBy('divided by', '/', 2);

  /// The English name of [this].
  final String name;

  /// The CSS syntax for [this].
  final String operator;

  /// The precedence of [this].
  ///
  /// An operator with higher precedence binds tighter.
  ///
  /// @nodoc
  @internal
  final int precedence;

  const CalculationOperator(this.name, this.operator, this.precedence);

  String toString() => name;
}

/// A string injected into a [SassCalculation] using interpolation.
///
/// This is tracked separately from string arguments because it requires
/// additional parentheses when used as an operand of a [CalculationOperation].
///
/// {@category Value}
@sealed
class CalculationInterpolation {
  /// We use a getters to allow overriding the logic in the JS API
  /// implementation.

  String get value => _value;
  final String _value;

  CalculationInterpolation(this._value);

  bool operator ==(Object other) =>
      other is CalculationInterpolation && value == other.value;

  int get hashCode => value.hashCode;

  String toString() => value;
}
