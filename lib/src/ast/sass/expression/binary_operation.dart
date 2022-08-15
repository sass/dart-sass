// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A binary operator, as in `1 + 2` or `$this and $other`.
///
/// {@category AST}
@sealed
class BinaryOperationExpression implements Expression {
  /// The operator being invoked.
  final BinaryOperator operator;

  /// The left-hand operand.
  final Expression left;

  /// The right-hand operand.
  final Expression right;

  /// Whether this is a [BinaryOperator.dividedBy] operation that may be
  /// interpreted as slash-separated numbers.
  ///
  /// @nodoc
  @internal
  final bool allowsSlash;

  FileSpan get span {
    // Avoid creating a bunch of intermediate spans for multiple binary
    // expressions in a row by moving to the left- and right-most expressions.
    var left = this.left;
    while (left is BinaryOperationExpression) {
      left = left.left;
    }

    var right = this.right;
    while (right is BinaryOperationExpression) {
      right = right.right;
    }
    return left.span.expand(right.span);
  }

  BinaryOperationExpression(this.operator, this.left, this.right)
      : allowsSlash = false;

  /// Creates a [BinaryOperator.dividedBy] operation that may be interpreted as
  /// slash-separated numbers.
  ///
  /// @nodoc
  @internal
  BinaryOperationExpression.slash(this.left, this.right)
      : operator = BinaryOperator.dividedBy,
        allowsSlash = true;

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitBinaryOperationExpression(this);

  String toString() {
    var buffer = StringBuffer();

    var left = this.left; // Hack to make analysis work.
    var leftNeedsParens = left is BinaryOperationExpression &&
        left.operator.precedence < operator.precedence;
    if (leftNeedsParens) buffer.writeCharCode($lparen);
    buffer.write(left);
    if (leftNeedsParens) buffer.writeCharCode($rparen);

    buffer.writeCharCode($space);
    buffer.write(operator.operator);
    buffer.writeCharCode($space);

    var right = this.right; // Hack to make analysis work.
    var rightNeedsParens = right is BinaryOperationExpression &&
        right.operator.precedence <= operator.precedence;
    if (rightNeedsParens) buffer.writeCharCode($lparen);
    buffer.write(right);
    if (rightNeedsParens) buffer.writeCharCode($rparen);

    return buffer.toString();
  }
}

/// A binary operator constant.
///
/// {@category AST}
enum BinaryOperator {
  /// The Microsoft equals operator, `=`.
  singleEquals('single equals', '=', 0),

  /// The disjunction operator, `or`.
  or('or', 'or', 1),

  /// The conjunction operator, `and`.
  and('and', 'and', 2),

  /// The equality operator, `==`.
  equals('equals', '==', 3),

  /// The inequality operator, `!=`.
  notEquals('not equals', '!=', 3),

  /// The greater-than operator, `>`.
  greaterThan('greater than', '>', 4),

  /// The greater-than-or-equal-to operator, `>=`.
  greaterThanOrEquals('greater than or equals', '>=', 4),

  /// The less-than operator, `<`.
  lessThan('less than', '<', 4),

  /// The less-than-or-equal-to operator, `<=`.
  lessThanOrEquals('less than or equals', '<=', 4),

  /// The addition operator, `+`.
  plus('plus', '+', 5),

  /// The subtraction operator, `-`.
  minus('minus', '-', 5),

  /// The multiplication operator, `*`.
  times('times', '*', 6),

  /// The division operator, `/`.
  dividedBy('divided by', '/', 6),

  /// The modulo operator, `%`.
  modulo('modulo', '%', 6);

  /// The English name of [this].
  final String name;

  /// The Sass syntax for [this].
  final String operator;

  /// The precedence of [this].
  ///
  /// An operator with higher precedence binds tighter.
  final int precedence;

  const BinaryOperator(this.name, this.operator, this.precedence);

  String toString() => name;
}
