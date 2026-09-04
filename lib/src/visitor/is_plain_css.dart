// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import 'interface/expression.dart';
import 'interface/if_condition_expression.dart';

// We could use [AstSearchVisitor] to implement this more tersely, but that
// would default to returning `true` if we added a new expression type and
// forgot to update this class.

/// A visitor that determines whether an expression is valid plain CSS that will
/// produce the same result as it would in Sass.
///
/// This should be used through [Expression.isPlainCss].
class IsPlainCssVisitor
    implements ExpressionVisitor<bool>, IfConditionExpressionVisitor<bool> {
  /// Whether to allow interpolation to as an exception to allowing plain CSS.
  final bool _allowInterpolation;

  /// If [allowInterpolation] is true, interpolated expressions are allowed as
  /// an exception, even if they contain SassScript.
  const IsPlainCssVisitor({bool allowInterpolation = false})
      : _allowInterpolation = allowInterpolation;

  bool visitBinaryOperationExpression(BinaryOperationExpression node) => false;

  bool visitBooleanExpression(BooleanExpression node) => false;

  bool visitColorExpression(ColorExpression node) => true;

  bool visitFunctionExpression(FunctionExpression node) =>
      node.namespace == null && _visitArgumentList(node.arguments);

  bool visitIfExpression(IfExpression node) =>
      node.branches.every((pair) => switch (pair) {
            (var condition?, var branch) =>
              condition.accept(this) && branch.accept(this),
            (_, var branch) => branch.accept(this),
          });

  bool visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) =>
      _allowInterpolation && _visitArgumentList(node.arguments);

  bool visitLegacyIfExpression(LegacyIfExpression node) => false;

  bool visitListExpression(ListExpression node) =>
      (node.contents.isNotEmpty || node.hasBrackets) &&
      node.contents.every((element) => element.accept(this));

  bool visitMapExpression(MapExpression node) => false;

  bool visitNullExpression(NullExpression node) => false;

  bool visitNumberExpression(NumberExpression node) => true;

  bool visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  bool visitSelectorExpression(SelectorExpression node) => false;

  bool visitStringExpression(StringExpression node) =>
      _allowInterpolation || node.text.isPlain;

  bool visitSupportsExpression(SupportsExpression node) => false;

  bool visitUnaryOperationExpression(UnaryOperationExpression node) => false;

  bool visitValueExpression(ValueExpression node) => false;

  bool visitVariableExpression(VariableExpression node) => false;

  bool visitIfConditionParenthesized(IfConditionParenthesized node) =>
      node.expression.accept(this);

  bool visitIfConditionNegation(IfConditionNegation node) =>
      node.expression.accept(this);

  bool visitIfConditionOperation(IfConditionOperation node) =>
      node.expressions.every((expression) => expression.accept(this));

  bool visitIfConditionFunction(IfConditionFunction node) =>
      _allowInterpolation || (node.name.isPlain && node.arguments.isPlain);

  bool visitIfConditionSass(IfConditionSass node) => false;

  bool visitIfConditionRaw(IfConditionRaw node) =>
      _allowInterpolation || node.text.isPlain;

  /// Returns whether [arguments] contains only plain CSS.
  bool _visitArgumentList(ArgumentList node) =>
      node.named.isEmpty &&
      node.rest == null &&
      node.positional.every((argument) => argument.accept(this));
}
