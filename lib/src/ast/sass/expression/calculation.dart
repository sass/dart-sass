// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'binary_operation.dart';
import 'function.dart';
import 'if.dart';
import 'number.dart';
import 'parenthesized.dart';
import 'string.dart';
import 'variable.dart';

/// A calculation literal.
///
/// {@category AST}
final class CalculationExpression implements Expression {
  /// This calculation's name.
  final String name;

  /// The arguments for the calculation.
  final List<Expression> arguments;

  final FileSpan span;

  /// Returns a `calc()` calculation expression.
  CalculationExpression.calc(Expression argument, FileSpan span)
      : this("calc", [argument], span);

  /// Returns a `min()` calculation expression.
  CalculationExpression.min(Iterable<Expression> arguments, this.span)
      : name = "min",
        arguments = _verifyArguments(arguments) {
    if (this.arguments.isEmpty) {
      throw ArgumentError("min() requires at least one argument.");
    }
  }

  /// Returns a `hypot()` calculation expression.
  CalculationExpression.hypot(Iterable<Expression> arguments, FileSpan span)
      : this("hypot", arguments, span);

  /// Returns a `max()` calculation expression.
  CalculationExpression.max(Iterable<Expression> arguments, this.span)
      : name = "max",
        arguments = _verifyArguments(arguments) {
    if (this.arguments.isEmpty) {
      throw ArgumentError("max() requires at least one argument.");
    }
  }

  /// Returns a `sqrt()` calculation expression.
  CalculationExpression.sqrt(Expression argument, FileSpan span)
      : this("sqrt", [argument], span);

  /// Returns a `sin()` calculation expression.
  CalculationExpression.sin(Expression argument, FileSpan span)
      : this("sin", [argument], span);

  /// Returns a `cos()` calculation expression.
  CalculationExpression.cos(Expression argument, FileSpan span)
      : this("cos", [argument], span);

  /// Returns a `tan()` calculation expression.
  CalculationExpression.tan(Expression argument, FileSpan span)
      : this("tan", [argument], span);

  /// Returns a `asin()` calculation expression.
  CalculationExpression.asin(Expression argument, FileSpan span)
      : this("asin", [argument], span);

  /// Returns a `acos()` calculation expression.
  CalculationExpression.acos(Expression argument, FileSpan span)
      : this("acos", [argument], span);

  /// Returns a `atan()` calculation expression.
  CalculationExpression.atan(Expression argument, FileSpan span)
      : this("atan", [argument], span);

  /// Returns a `abs()` calculation expression.
  CalculationExpression.abs(Expression argument, FileSpan span)
      : this("abs", [argument], span);

  /// Returns a `sign()` calculation expression.
  CalculationExpression.sign(Expression argument, FileSpan span)
      : this("sign", [argument], span);

  /// Returns a `exp()` calculation expression.
  CalculationExpression.exp(Expression argument, FileSpan span)
      : this("exp", [argument], span);

  /// Returns a `clamp()` calculation expression.
  CalculationExpression.clamp(
      Expression min, Expression value, Expression max, FileSpan span)
      : this("clamp", [min, max, value], span);

  /// Returns a `pow()` calculation expression.
  CalculationExpression.pow(Expression base, Expression exponent, FileSpan span)
      : this("pow", [base, exponent], span);

  /// Returns a `log()` calculation expression.
  CalculationExpression.log(Expression number, Expression base, FileSpan span)
      : this("log", [number, base], span);

  /// Returns a `round()` calculation expression.
  CalculationExpression.round(
      Expression strategy, Expression number, Expression step, FileSpan span)
      : this("round", [strategy, number, step], span);

  /// Returns a `atan2()` calculation expression.
  CalculationExpression.atan2(Expression y, Expression x, FileSpan span)
      : this("atan2", [y, x], span);

  /// Returns a `mod()` calculation expression.
  CalculationExpression.mod(Expression y, Expression x, FileSpan span)
      : this("mod", [y, x], span);

  /// Returns a `rem()` calculation expression.
  CalculationExpression.rem(Expression y, Expression x, FileSpan span)
      : this("rem", [y, x], span);

  /// Returns a calculation expression with the given name and arguments.
  ///
  /// Unlike the other constructors, this doesn't verify that the arguments are
  /// valid for the name.
  @internal
  CalculationExpression(this.name, Iterable<Expression> arguments, this.span)
      : arguments = _verifyArguments(arguments);

  /// Throws an [ArgumentError] if [arguments] aren't valid calculation
  /// arguments, and returns them as an unmodifiable list if they are.
  static List<Expression> _verifyArguments(Iterable<Expression> arguments) =>
      List.unmodifiable(arguments.map((arg) {
        _verify(arg);
        return arg;
      }));

  /// Throws an [ArgumentError] if [expression] isn't a valid calculation
  /// argument.
  static void _verify(Expression expression) {
    switch (expression) {
      case NumberExpression() ||
            CalculationExpression() ||
            VariableExpression() ||
            FunctionExpression() ||
            IfExpression() ||
            StringExpression(hasQuotes: false):
        break;

      case ParenthesizedExpression(:var expression):
        _verify(expression);

      case BinaryOperationExpression(
          :var left,
          :var right,
          operator: BinaryOperator.plus ||
              BinaryOperator.minus ||
              BinaryOperator.times ||
              BinaryOperator.dividedBy
        ):
        _verify(left);
        _verify(right);

      case _:
        throw ArgumentError("Invalid calculation argument $expression.");
    }
  }

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitCalculationExpression(this);

  String toString() => "$name(${arguments.join(', ')})";
}
