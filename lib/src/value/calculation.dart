// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../exception.dart';
import '../util/nullable.dart';
import '../util/number.dart';
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

  /// Creates a `calc()` calculation with the given [argument].
  ///
  /// The [argument] must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation].
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
  /// [SassNumber] rather than a [SassCalculation].
  static Value min(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("min() must have at least one argument.");
    }

    SassNumber? minimum;
    for (var arg in args) {
      if (arg is! SassNumber ||
          (minimum != null && !minimum.hasCompatibleUnits(arg))) {
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
  /// [SassNumber] rather than a [SassCalculation].
  static Value max(Iterable<Object> arguments) {
    var args = _simplifyArguments(arguments);
    if (args.isEmpty) {
      throw ArgumentError("max() must have at least one argument.");
    }

    SassNumber? maximum;
    for (var arg in args) {
      if (arg is! SassNumber ||
          (maximum != null && !maximum.hasCompatibleUnits(arg))) {
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

  /// Creates a `clamp()` calculation with the given [min], [value], and [max].
  ///
  /// Each argument must be either a [SassNumber], a [SassCalculation], an
  /// unquoted [SassString], a [CalculationOperation], or a
  /// [CalculationInterpolation].
  ///
  /// This automatically simplifies the calculation, so it may return a
  /// [SassNumber] rather than a [SassCalculation].
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
      CalculationOperator operator, Object left, Object right) {
    left = _simplify(left);
    right = _simplify(right);

    if (operator == CalculationOperator.plus ||
        operator == CalculationOperator.minus) {
      if (left is SassNumber &&
          right is SassNumber &&
          left.hasCompatibleUnits(right)) {
        return operator == CalculationOperator.plus
            ? left.plus(right)
            : left.minus(right);
      }

      _verifyCompatibleNumbers([left, right]);

      if (right is SassNumber && fuzzyLessThan(right.value, 0)) {
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
      throw _exception("Quoted string $arg can't be used in a calculation.");
    } else if (arg is SassCalculation) {
      return arg.name == 'calc' ? arg.arguments[0] : arg;
    } else if (arg is Value) {
      throw _exception("Value $arg can't be used in a calculation.");
    } else {
      throw ArgumentError("Unexpected calculation argument $arg.");
    }
  }

  /// Verifies that all the numbers in [args] aren't known to be incomaptible
  /// with one another, and that they don't have units that are too complex for
  /// calculations.
  static void _verifyCompatibleNumbers(List<Object> args) {
    // Note: this logic is largely duplicated in
    // _EvaluateVisitor._verifyCompatibleNumbers and most changes here should
    // also be reflected there.
    for (var arg in args) {
      if (arg is! SassNumber) continue;
      if (arg.numeratorUnits.length > 1 || arg.denominatorUnits.isNotEmpty) {
        throw _exception("Number $arg isn't compatible with CSS calculations.");
      }
    }

    for (var i = 0; i < args.length - 1; i++) {
      var number1 = args[i];
      if (number1 is! SassNumber) continue;

      for (var j = i + 1; j < args.length; j++) {
        var number2 = args[j];
        if (number2 is! SassNumber) continue;
        if (number1.hasPossiblyCompatibleUnits(number2)) continue;
        throw _exception("$number1 and $number2 are incompatible.");
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
    throw _exception(
        "$expectedLength arguments required, but only ${args.length} "
        "${pluralize('was', args.length, plural: 'were')} passed.");
  }

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitCalculation(this);

  SassCalculation assertCalculation([String? name]) => this;

  /// @nodoc
  @internal
  Value plus(Value other) =>
      throw SassScriptException('Undefined operation "$this + $other".');

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

  /// Throws a [SassScriptException] with the given [message].
  static SassScriptException _exception(String message, [String? name]) =>
      SassScriptException(name == null ? message : "\$$name: $message");
}

/// A binary operation that can appear in a [SassCalculation].
///
/// {@category Value}
@sealed
class CalculationOperation {
  /// The operator.
  final CalculationOperator operator;

  /// The left-hand operand.
  ///
  /// This is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], a [CalculationOperation], or a [CalculationInterpolation].
  final Object left;

  /// The right-hand operand.
  ///
  /// This is either a [SassNumber], a [SassCalculation], an unquoted
  /// [SassString], a [CalculationOperation], or a [CalculationInterpolation].
  final Object right;

  CalculationOperation._(this.operator, this.left, this.right);

  bool operator ==(Object other) =>
      other is CalculationOperation &&
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
@sealed
class CalculationOperator {
  /// The addition operator.
  static const plus = CalculationOperator._("plus", "+", 1);

  /// The subtraction operator.
  static const minus = CalculationOperator._("minus", "-", 1);

  /// The multiplication operator.
  static const times = CalculationOperator._("times", "*", 2);

  /// The division operator.
  static const dividedBy = CalculationOperator._("divided by", "/", 2);

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

  const CalculationOperator._(this.name, this.operator, this.precedence);

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
  final String value;

  CalculationInterpolation(this.value);

  bool operator ==(Object other) =>
      other is CalculationInterpolation && value == other.value;

  int get hashCode => value.hashCode;

  String toString() => value;
}
