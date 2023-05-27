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
@sealed
class CalculationExpression implements Expression {
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
    if (expression is NumberExpression) return;
    if (expression is CalculationExpression) return;
    if (expression is VariableExpression) return;
    if (expression is FunctionExpression) return;
    if (expression is IfExpression) return;

    if (expression is StringExpression) {
      if (expression.hasQuotes) {
        throw ArgumentError("Invalid calculation argument $expression.");
      }
    } else if (expression is ParenthesizedExpression) {
      _verify(expression.expression);
    } else if (expression is BinaryOperationExpression) {
      _verify(expression.left);
      _verify(expression.right);
      if (expression.operator == BinaryOperator.plus) return;
      if (expression.operator == BinaryOperator.minus) return;
      if (expression.operator == BinaryOperator.times) return;
      if (expression.operator == BinaryOperator.dividedBy) return;

      throw ArgumentError("Invalid calculation argument $expression.");
    } else {
      throw ArgumentError("Invalid calculation argument $expression.");
    }
  }

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitCalculationExpression(this);

  String toString() => "$name(${arguments.join(', ')})";
}
