// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'binary_operation.dart';
import 'list.dart';

/// A unary operator, as in `+$var` or `not fn()`.
///
/// {@category AST}
final class UnaryOperationExpression extends Expression {
  /// The operator being invoked.
  final UnaryOperator operator;

  /// The operand.
  final Expression operand;

  final FileSpan span;

  UnaryOperationExpression(this.operator, this.operand, this.span);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitUnaryOperationExpression(this);

  String toString() {
    var buffer = StringBuffer(operator.operator);
    if (operator == UnaryOperator.not) buffer.writeCharCode($space);
    var operand = this.operand;
    var needsParens = switch (operand) {
      BinaryOperationExpression() ||
      UnaryOperationExpression() ||
      ListExpression(hasBrackets: false, contents: [_, _, ...]) =>
        true,
      _ => false
    };
    if (needsParens) buffer.write($lparen);
    buffer.write(operand);
    if (needsParens) buffer.write($rparen);
    return buffer.toString();
  }
}

/// A unary operator constant.
///
/// {@category AST}
enum UnaryOperator {
  /// The numeric identity operator, `+`.
  plus('plus', '+'),

  /// The numeric negation operator, `-`.
  minus('minus', '-'),

  /// The leading slash operator, `/`.
  ///
  /// This is a historical artifact.
  divide('divide', '/'),

  /// The boolean negation operator, `not`.
  not('not', 'not');

  /// The English name of `this`.
  final String name;

  /// The Sass syntax for `this`.
  final String operator;

  const UnaryOperator(this.name, this.operator);

  String toString() => name;
}
