// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:charcode/charcode.dart';

import '../../../utils.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A binary operator, as in `1 + 2` or `$this and $other`.
class BinaryOperationExpression implements Expression {
  /// The operator being invoked.
  final BinaryOperator operator;

  /// The left-hand operand.
  final Expression left;

  /// The right-hand operand.
  final Expression right;

  /// Whether this is a [BinaryOperator.dividedBy] operation that may be
  /// interpreted as slash-separated numbers.
  final bool allowsSlash;

  FileSpan get span => spanForList([left, right]);

  BinaryOperationExpression(this.operator, this.left, this.right)
      : allowsSlash = false;

  /// Creates a [BinaryOperator.dividedBy] operation that may be interpreted as
  /// slash-separated numbers.
  BinaryOperationExpression.slash(this.left, this.right)
      : operator = BinaryOperator.dividedBy,
        allowsSlash = true;

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitBinaryOperationExpression(this);

  String toString() {
    var buffer = new StringBuffer();

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
class BinaryOperator {
  /// The Microsoft equals operator, `=`.
  static const singleEquals = const BinaryOperator._("single equals", "=", 0);

  /// The disjunction operator, `or`.
  static const or = const BinaryOperator._("or", "or", 1);

  /// The conjunction operator, `and`.
  static const and = const BinaryOperator._("and", "and", 2);

  /// The equality operator, `==`.
  static const equals = const BinaryOperator._("equals", "==", 3);

  /// The inequality operator, `!=`.
  static const notEquals = const BinaryOperator._("not equals", "!=", 3);

  /// The greater-than operator, `>`.
  static const greaterThan = const BinaryOperator._("greater than", ">", 4);

  /// The greater-than-or-equal-to operator, `>=`.
  static const greaterThanOrEquals =
      const BinaryOperator._("greater than or equals", ">=", 4);

  /// The less-than operator, `<`.
  static const lessThan = const BinaryOperator._("less than", "<", 4);

  /// The less-than-or-equal-to operator, `<=`.
  static const lessThanOrEquals =
      const BinaryOperator._("less than or equals", "<=", 4);

  /// The addition operator, `+`.
  static const plus = const BinaryOperator._("plus", "+", 5);

  /// The subtraction operator, `+`.
  static const minus = const BinaryOperator._("minus", "-", 5);

  /// The multiplication operator, `*`.
  static const times = const BinaryOperator._("times", "*", 6);

  /// The division operator, `/`.
  static const dividedBy = const BinaryOperator._("divided by", "/", 6);

  /// The modulo operator, `%`.
  static const modulo = const BinaryOperator._("modulo", "%", 6);

  /// The English name of [this].
  final String name;

  /// The Sass syntax for [this].
  final String operator;

  /// The precedence of [this].
  ///
  /// An operator with higher precedence binds tighter.
  final int precedence;

  const BinaryOperator._(this.name, this.operator, this.precedence);

  String toString() => name;
}
