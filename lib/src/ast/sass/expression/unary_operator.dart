// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:charcode/charcode.dart';

import '../../../visitor/sass/expression.dart';
import '../expression.dart';

class UnaryOperatorExpression implements Expression {
  final UnaryOperator operator;

  final Expression operand;

  final SourceSpan span;

  UnaryOperatorExpression(this.operator, this.operand, {this.span});

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitUnaryOperatorExpression(this);

  String toString() {
    var buffer = new StringBuffer(operator.operator);
    if (operator == UnaryOperator.not) buffer.writeCharCode($space);
    buffer.write(operand);
    return buffer.toString();
  }
}

class UnaryOperator {
  static const plus = const UnaryOperator._("plus", "+");
  static const minus = const UnaryOperator._("minus", "-");
  static const divide = const UnaryOperator._("divide", "/");
  static const not = const UnaryOperator._("not", "not");

  final String name;

  final String operator;

  const UnaryOperator._(this.name, this.operator);

  String toString() => name;
}
