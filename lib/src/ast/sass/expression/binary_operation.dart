// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:charcode/charcode.dart';

import '../../../utils.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';

class BinaryOperationExpression implements Expression {
  final BinaryOperator operator;

  final Expression left;

  final Expression right;

  FileSpan get span => spanForList([left, right]);

  BinaryOperationExpression(this.operator, this.left, this.right);

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
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

class BinaryOperator {
  static const or = const BinaryOperator._("or", "or", 0);
  static const and = const BinaryOperator._("and", "and", 1);
  static const equals = const BinaryOperator._("equals", "==", 2);
  static const notEquals = const BinaryOperator._("not equals", "!=", 2);
  static const greaterThan = const BinaryOperator._("greater than", ">", 3);
  static const greaterThanOrEquals =
      const BinaryOperator._("greater than or equals", ">=", 3);
  static const lessThan = const BinaryOperator._("less than", "<", 3);
  static const lessThanOrEquals =
      const BinaryOperator._("less than or equals", "<=", 3);
  static const plus = const BinaryOperator._("plus", "+", 4);
  static const minus = const BinaryOperator._("minus", "-", 4);
  static const times = const BinaryOperator._("times", "*", 5);
  static const dividedBy = const BinaryOperator._("divided by", "/", 5);
  static const modulo = const BinaryOperator._("modulo", "%", 5);

  final String name;

  final String operator;

  final int precedence;

  const BinaryOperator._(this.name, this.operator, this.precedence);

  String toString() => name;
}
