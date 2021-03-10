// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:charcode/charcode.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A unary operator, as in `+$var` or `not fn()`.
class UnaryOperationExpression implements Expression {
  /// The operator being invoked.
  final UnaryOperator/*!*/ operator;

  /// The operand.
  final Expression/*!*/ operand;

  final FileSpan span;

  UnaryOperationExpression(this.operator, this.operand, this.span);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitUnaryOperationExpression(this);

  String toString() {
    var buffer = StringBuffer(operator.operator);
    if (operator == UnaryOperator.not) buffer.writeCharCode($space);
    buffer.write(operand);
    return buffer.toString();
  }
}

/// A unary operator constant.
class UnaryOperator {
  /// The numeric identity operator, `+`.
  static const plus = UnaryOperator._("plus", "+");

  /// The numeric negation operator, `-`.
  static const minus = UnaryOperator._("minus", "-");

  /// The leading slash operator, `/`.
  ///
  /// This is a historical artifact.
  static const divide = UnaryOperator._("divide", "/");

  /// The boolean negation operator, `not`.
  static const not = UnaryOperator._("not", "not");

  /// The English name of [this].
  final String name;

  /// The Sass syntax for [this].
  final String operator;

  const UnaryOperator._(this.name, this.operator);

  String toString() => name;
}
