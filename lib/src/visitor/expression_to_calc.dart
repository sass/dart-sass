// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import 'replace_expression.dart';

/// Converts [expression] to an equivalent `calc()`.
///
/// This assumes that [expression] already returns a number. It's intended for
/// use in end-user messaging, and may not produce directly evaluable
/// expressions.
FunctionExpression expressionToCalc(Expression expression) =>
    FunctionExpression(
        "calc",
        ArgumentInvocation(
            [expression.accept(const _MakeExpressionCalculationSafe())],
            const {},
            expression.span),
        expression.span);

/// A visitor that replaces constructs that can't be used in a calculation with
/// those that can.
class _MakeExpressionCalculationSafe with ReplaceExpressionVisitor {
  const _MakeExpressionCalculationSafe();

  Expression visitBinaryOperationExpression(BinaryOperationExpression node) => node
              .operator ==
          BinaryOperator.modulo
      // `calc()` doesn't support `%` for modulo but Sass doesn't yet support the
      // `mod()` calculation function because there's no browser support, so we have
      // to work around it by wrapping the call in a Sass function.
      ? FunctionExpression(
          'max', ArgumentInvocation([node], const {}, node.span), node.span,
          namespace: 'math')
      : super.visitBinaryOperationExpression(node);

  Expression visitInterpolatedFunctionExpression(
          InterpolatedFunctionExpression node) =>
      node;

  Expression visitUnaryOperationExpression(UnaryOperationExpression node) =>
      switch (node.operator) {
        // `calc()` doesn't support unary operations.
        UnaryOperator.plus => node.operand,
        UnaryOperator.minus => BinaryOperationExpression(BinaryOperator.times,
            NumberExpression(-1, node.span), node.operand),
        _ =>
          // Other unary operations don't produce numbers, so keep them as-is to
          // give the user a more useful syntax error after serialization.
          super.visitUnaryOperationExpression(node)
      };
}
