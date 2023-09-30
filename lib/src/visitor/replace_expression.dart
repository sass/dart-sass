// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../util/map.dart';
import 'interface/expression.dart';

/// A visitor that recursively traverses each expression in a SassScript AST and
/// replaces its contents with the values returned by nested recursion.
///
/// In addition to the methods from [ExpressionVisitor], this has more general
/// protected methods that can be overridden to add behavior for a wide variety
/// of AST nodes:
///
/// * [visitArgumentInvocation]
/// * [visitSupportsCondition]
/// * [visitInterpolation]
///
/// {@category Visitor}
mixin ReplaceExpressionVisitor implements ExpressionVisitor<Expression> {
  Expression visitBinaryOperationExpression(BinaryOperationExpression node) =>
      BinaryOperationExpression(
          node.operator, node.left.accept(this), node.right.accept(this));

  Expression visitBooleanExpression(BooleanExpression node) => node;

  Expression visitColorExpression(ColorExpression node) => node;

  Expression visitFunctionExpression(
          FunctionExpression node) =>
      FunctionExpression(
          node.originalName, visitArgumentInvocation(node.arguments), node.span,
          namespace: node.namespace);

  Expression visitInterpolatedFunctionExpression(
          InterpolatedFunctionExpression node) =>
      InterpolatedFunctionExpression(visitInterpolation(node.name),
          visitArgumentInvocation(node.arguments), node.span);

  Expression visitIfExpression(IfExpression node) =>
      IfExpression(visitArgumentInvocation(node.arguments), node.span);

  Expression visitListExpression(ListExpression node) => ListExpression(
      node.contents.map((item) => item.accept(this)), node.separator, node.span,
      brackets: node.hasBrackets);

  Expression visitMapExpression(MapExpression node) => MapExpression([
        for (var (key, value) in node.pairs)
          (key.accept(this), value.accept(this))
      ], node.span);

  Expression visitNullExpression(NullExpression node) => node;

  Expression visitNumberExpression(NumberExpression node) => node;

  Expression visitParenthesizedExpression(ParenthesizedExpression node) =>
      ParenthesizedExpression(node.expression.accept(this), node.span);

  Expression visitSelectorExpression(SelectorExpression node) => node;

  Expression visitStringExpression(StringExpression node) =>
      StringExpression(visitInterpolation(node.text), quotes: node.hasQuotes);

  Expression visitSupportsExpression(SupportsExpression node) =>
      SupportsExpression(visitSupportsCondition(node.condition));

  Expression visitUnaryOperationExpression(UnaryOperationExpression node) =>
      UnaryOperationExpression(
          node.operator, node.operand.accept(this), node.span);

  Expression visitValueExpression(ValueExpression node) => node;

  Expression visitVariableExpression(VariableExpression node) => node;

  /// Replaces each expression in an [invocation].
  ///
  /// The default implementation of the visit methods calls this to replace any
  /// argument invocation in an expression.
  @protected
  ArgumentInvocation visitArgumentInvocation(ArgumentInvocation invocation) =>
      ArgumentInvocation(
          invocation.positional.map((expression) => expression.accept(this)),
          {
            for (var (name, value) in invocation.named.pairs)
              name: value.accept(this)
          },
          invocation.span,
          rest: invocation.rest?.accept(this),
          keywordRest: invocation.keywordRest?.accept(this));

  /// Replaces each expression in [condition].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// [SupportsCondition] they encounter.
  @protected
  SupportsCondition visitSupportsCondition(SupportsCondition condition) {
    if (condition is SupportsOperation) {
      return SupportsOperation(
          visitSupportsCondition(condition.left),
          visitSupportsCondition(condition.right),
          condition.operator,
          condition.span);
    } else if (condition is SupportsNegation) {
      return SupportsNegation(
          visitSupportsCondition(condition.condition), condition.span);
    } else if (condition is SupportsInterpolation) {
      return SupportsInterpolation(
          condition.expression.accept(this), condition.span);
    } else if (condition is SupportsDeclaration) {
      return SupportsDeclaration(condition.name.accept(this),
          condition.value.accept(this), condition.span);
    } else {
      throw SassException(
          "BUG: Unknown SupportsCondition $condition.", condition.span);
    }
  }

  /// Replaces each expression in an [interpolation].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// interpolation in an expression.
  @protected
  Interpolation visitInterpolation(Interpolation interpolation) =>
      Interpolation(
          interpolation.contents
              .map((node) => node is Expression ? node.accept(this) : node),
          interpolation.span);
}
