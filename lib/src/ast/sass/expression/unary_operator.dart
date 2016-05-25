// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:charcode/charcode.dart';

import '../../../visitor/expression.dart';
import '../expression.dart';

class UnaryOperatorExpression implements Expression {
  final UnaryOperator operator;

  final Expression operand;

  final SourceSpan span;

  UnaryOperatorExpression(this.operator, this.operand, {this.span});

  /*=T*/ visit/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitUnaryOperatorExpression(this);

  String toString() => "${operator.operator}${operand}";
}

class UnaryOperator {
  static const plus = const UnaryOperator._("plus", "+");
  static const minus = const UnaryOperator._("minus", "-");
  static const divide = const UnaryOperator._("divide", "/");

  final String name;

  final String operator;

  const UnaryOperator._(this.name, this.operator);

  String toString() => name;
}
