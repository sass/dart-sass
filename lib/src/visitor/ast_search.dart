// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import '../util/iterable.dart';
import '../util/nullable.dart';
import 'interface/expression.dart';
import 'interface/if_condition_expression.dart';
import 'interface/interpolated_selector.dart';
import 'statement_search.dart';

/// A visitor that recursively traverses each statement and expression in a Sass
/// AST whose `visit*` methods default to returning `null`, but which returns
/// the first non-`null` value returned by any method.
///
/// This extends [StatementSearchVisitor] to traverse each expression in
/// addition to each statement, as well as each selector for ASTs where
/// `parseSelectors: true` was passed to [Stylesheet.parse]. It supports the
/// same additional methods as [RecursiveAstVisitor].
///
/// {@category Visitor}
mixin AstSearchVisitor<T> on StatementSearchVisitor<T>
    implements
        ExpressionVisitor<T?>,
        IfConditionExpressionVisitor<T?>,
        InterpolatedSelectorVisitor<T?> {
  // Rules

  @override
  T? visitAtRootRule(AtRootRule node) =>
      node.query.andThen(visitInterpolation) ?? super.visitAtRootRule(node);

  @override
  T? visitAtRule(AtRule node) =>
      visitInterpolation(node.name) ??
      node.value.andThen(visitInterpolation) ??
      super.visitAtRule(node);

  @override
  T? visitContentRule(ContentRule node) => visitArgumentList(node.arguments);

  @override
  T? visitDebugRule(DebugRule node) => visitExpression(node.expression);

  @override
  T? visitDeclaration(Declaration node) =>
      visitInterpolation(node.name) ??
      node.value.andThen(visitExpression) ??
      super.visitDeclaration(node);

  @override
  T? visitEachRule(EachRule node) =>
      visitExpression(node.list) ?? super.visitEachRule(node);

  @override
  T? visitErrorRule(ErrorRule node) => visitExpression(node.expression);

  @override
  T? visitExtendRule(ExtendRule node) => visitInterpolation(node.selector);

  @override
  T? visitForRule(ForRule node) =>
      visitExpression(node.from) ??
      visitExpression(node.to) ??
      super.visitForRule(node);

  @override
  T? visitForwardRule(ForwardRule node) => node.configuration.search(
        (variable) => visitExpression(variable.expression),
      );

  @override
  T? visitIfRule(IfRule node) =>
      node.clauses.search(
        (clause) =>
            visitExpression(clause.expression) ??
            clause.children.search((child) => child.accept(this)),
      ) ??
      node.lastClause.andThen(
        (lastClause) =>
            lastClause.children.search((child) => child.accept(this)),
      );

  @override
  T? visitImportRule(ImportRule node) => node.imports.search(
        (import) => import is StaticImport
            ? visitInterpolation(import.url) ??
                import.modifiers.andThen(visitInterpolation)
            : null,
      );

  @override
  T? visitIncludeRule(IncludeRule node) =>
      visitArgumentList(node.arguments) ?? super.visitIncludeRule(node);

  @override
  T? visitLoudComment(LoudComment node) => visitInterpolation(node.text);

  @override
  T? visitMediaRule(MediaRule node) =>
      visitInterpolation(node.query) ?? super.visitMediaRule(node);

  @override
  T? visitReturnRule(ReturnRule node) => visitExpression(node.expression);

  @override
  T? visitStyleRule(StyleRule node) =>
      node.selector.andThen(visitInterpolation) ?? super.visitStyleRule(node);

  @override
  T? visitSupportsRule(SupportsRule node) =>
      visitSupportsCondition(node.condition) ?? super.visitSupportsRule(node);

  @override
  T? visitUseRule(UseRule node) => node.configuration.search(
        (variable) => visitExpression(variable.expression),
      );

  @override
  T? visitVariableDeclaration(VariableDeclaration node) =>
      visitExpression(node.expression);

  @override
  T? visitWarnRule(WarnRule node) => visitExpression(node.expression);

  @override
  T? visitWhileRule(WhileRule node) =>
      visitExpression(node.condition) ?? super.visitWhileRule(node);

  // Expressions

  T? visitExpression(Expression expression) => expression.accept(this);

  @override
  T? visitBinaryOperationExpression(BinaryOperationExpression node) =>
      node.left.accept(this) ?? node.right.accept(this);

  @override
  T? visitBooleanExpression(BooleanExpression node) => null;

  @override
  T? visitColorExpression(ColorExpression node) => null;

  @override
  T? visitFunctionExpression(FunctionExpression node) =>
      visitArgumentList(node.arguments);

  @override
  T? visitIfExpression(IfExpression node) => node.branches
      .search((pair) => pair.$1?.accept(this) ?? pair.$2.accept(this));

  @override
  T? visitInterpolatedFunctionExpression(InterpolatedFunctionExpression node) =>
      visitInterpolation(node.name) ?? visitArgumentList(node.arguments);

  @override
  T? visitLegacyIfExpression(LegacyIfExpression node) =>
      visitArgumentList(node.arguments);

  @override
  T? visitListExpression(ListExpression node) =>
      node.contents.search((item) => item.accept(this));

  @override
  T? visitMapExpression(MapExpression node) =>
      node.pairs.search((pair) => pair.$1.accept(this) ?? pair.$2.accept(this));

  @override
  T? visitNullExpression(NullExpression node) => null;

  @override
  T? visitNumberExpression(NumberExpression node) => null;

  @override
  T? visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  @override
  T? visitSelectorExpression(SelectorExpression node) => null;

  @override
  T? visitStringExpression(StringExpression node) =>
      visitInterpolation(node.text);

  @override
  T? visitSupportsExpression(SupportsExpression node) =>
      visitSupportsCondition(node.condition);

  @override
  T? visitUnaryOperationExpression(UnaryOperationExpression node) =>
      node.operand.accept(this);

  @override
  T? visitValueExpression(ValueExpression node) => null;

  @override
  T? visitVariableExpression(VariableExpression node) => null;

  // `if()` condition expresions

  @override
  T? visitIfConditionParenthesized(IfConditionParenthesized node) =>
      node.expression.accept(this);

  @override
  T? visitIfConditionNegation(IfConditionNegation node) =>
      node.expression.accept(this);

  @override
  T? visitIfConditionOperation(IfConditionOperation node) =>
      node.expressions.search((expression) => expression.accept(this));

  @override
  T? visitIfConditionFunction(IfConditionFunction node) =>
      visitInterpolation(node.name) ?? visitInterpolation(node.arguments);

  @override
  T? visitIfConditionSass(IfConditionSass node) => node.expression.accept(this);

  @override
  T? visitIfConditionRaw(IfConditionRaw node) => visitInterpolation(node.text);

  // Interpolated selectors

  @override
  T? visitAttributeSelector(InterpolatedAttributeSelector node) =>
      visitQualifiedName(node.name) ??
      node.value.andThen(visitInterpolation) ??
      node.modifier.andThen(visitInterpolation);

  @override
  T? visitClassSelector(InterpolatedClassSelector node) =>
      visitInterpolation(node.name);

  @override
  T? visitComplexSelector(InterpolatedComplexSelector node) => node.components
      .search((component) => visitCompoundSelector(component.selector));

  @override
  T? visitIDSelector(InterpolatedIDSelector node) =>
      visitInterpolation(node.name);

  @override
  T? visitParentSelector(InterpolatedParentSelector node) =>
      node.suffix.andThen(visitInterpolation);

  @override
  T? visitPlaceholderSelector(InterpolatedPlaceholderSelector node) =>
      visitInterpolation(node.name);

  @override
  T? visitPseudoSelector(InterpolatedPseudoSelector node) =>
      visitInterpolation(node.name) ??
      node.argument.andThen(visitInterpolation) ??
      node.selector.andThen(visitSelectorList);

  @override
  T? visitSelectorList(InterpolatedSelectorList node) =>
      node.components.search((component) => visitComplexSelector(component));

  @override
  T? visitTypeSelector(InterpolatedTypeSelector node) =>
      visitQualifiedName(node.name);

  T? visitUniverssalSelector(InterpolatedUniversalSelector node) =>
      node.namespace.andThen(visitInterpolation);

  @override
  @protected
  T? visitCallableDeclaration(CallableDeclaration node) =>
      node.parameters.parameters.search(
        (parameter) => parameter.defaultValue.andThen(visitExpression),
      ) ??
      super.visitCallableDeclaration(node);

  /// Visits each expression in an [invocation].
  ///
  /// The default implementation of the visit methods calls this to visit any
  /// argument invocation in a statement.
  @protected
  T? visitArgumentList(ArgumentList invocation) =>
      invocation.positional.search(
        (expression) => visitExpression(expression),
      ) ??
      invocation.named.values.search(
        (expression) => visitExpression(expression),
      ) ??
      invocation.rest.andThen(visitExpression) ??
      invocation.keywordRest.andThen(visitExpression);

  /// Visits each expression in [condition].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// [SupportsCondition] they encounter.
  @protected
  T? visitSupportsCondition(SupportsCondition condition) => switch (condition) {
        SupportsOperation() => visitSupportsCondition(condition.left) ??
            visitSupportsCondition(condition.right),
        SupportsNegation() => visitSupportsCondition(condition.condition),
        SupportsInterpolation() => visitExpression(condition.expression),
        SupportsDeclaration() =>
          visitExpression(condition.name) ?? visitExpression(condition.value),
        _ => null,
      };

  /// Visits each expression in an [interpolation].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// interpolation in a statement.
  @protected
  T? visitInterpolation(Interpolation interpolation) => interpolation.contents
      .search((node) => node is Expression ? visitExpression(node) : null);

  /// Visits each expression in [node].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// qualified names in a selector.
  @protected
  T? visitQualifiedName(InterpolatedQualifiedName node) =>
      node.namespace.andThen(visitInterpolation) ??
      visitInterpolation(node.name);
}
