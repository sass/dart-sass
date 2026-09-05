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

  @override
  bool visitBinaryOperationExpression(BinaryOperationExpression node) => false;

  @override
  bool visitBooleanExpression(BooleanExpression node) => false;

  @override
  bool visitColorExpression(ColorExpression node) => true;

  @override
  bool visitFunctionExpression(FunctionExpression node) =>
      node.namespace == null && _visitArgumentList(node.arguments);

  @override
  bool visitIfExpression(IfExpression node) =>
      node.branches.every((pair) => switch (pair) {
            (var condition?, var branch) =>
              condition.accept(this) && branch.accept(this),
            (_, var branch) => branch.accept(this),
          });

  @override
  bool visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) =>
      _allowInterpolation && _visitArgumentList(node.arguments);

  @override
  bool visitLegacyIfExpression(LegacyIfExpression node) => false;

  @override
  bool visitListExpression(ListExpression node) =>
      (node.contents.isNotEmpty || node.hasBrackets) &&
      node.contents.every((element) => element.accept(this));

  @override
  bool visitMapExpression(MapExpression node) => false;

  @override
  bool visitNullExpression(NullExpression node) => false;

  @override
  bool visitNumberExpression(NumberExpression node) => true;

  @override
  bool visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  @override
  bool visitSelectorExpression(SelectorExpression node) => false;

  @override
  bool visitStringExpression(StringExpression node) =>
      _allowInterpolation || node.text.isPlain;

  @override
  bool visitSupportsExpression(SupportsExpression node) => false;

  @override
  bool visitUnaryOperationExpression(UnaryOperationExpression node) => false;

  @override
  bool visitValueExpression(ValueExpression node) => false;

  @override
  bool visitVariableExpression(VariableExpression node) => false;

  @override
  bool visitIfConditionParenthesized(IfConditionParenthesized node) =>
      node.expression.accept(this);

  @override
  bool visitIfConditionNegation(IfConditionNegation node) =>
      node.expression.accept(this);

  @override
  bool visitIfConditionOperation(IfConditionOperation node) =>
      node.expressions.every((expression) => expression.accept(this));

  @override
  bool visitIfConditionFunction(IfConditionFunction node) =>
      _allowInterpolation || (node.name.isPlain && node.arguments.isPlain);

  @override
  bool visitIfConditionSass(IfConditionSass node) => false;

  @override
  bool visitIfConditionRaw(IfConditionRaw node) =>
      _allowInterpolation || node.text.isPlain;

  /// Returns whether [arguments] contains only plain CSS.
  bool _visitArgumentList(ArgumentList node) =>
      node.named.isEmpty &&
      node.rest == null &&
      node.positional.every((argument) => argument.accept(this));
}
