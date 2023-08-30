// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import '../util/iterable.dart';
import '../util/nullable.dart';
import 'interface/expression.dart';
import 'recursive_statement.dart';
import 'statement_search.dart';

/// An [AstVisitor] whose `visit*` methods default to returning `null`, but
/// which returns the first non-`null` value returned by any method.
///
/// This extends [RecursiveStatementVisitor] to traverse each expression in
/// addition to each statement. It supports the same additional methods as
/// [RecursiveAstVisitor].
///
/// {@category Visitor}
mixin AstSearchVisitor<T> on StatementSearchVisitor<T>
    implements ExpressionVisitor<T?> {
  T? visitAtRootRule(AtRootRule node) =>
      node.query.andThen(visitInterpolation) ?? super.visitAtRootRule(node);

  T? visitAtRule(AtRule node) =>
      visitInterpolation(node.name) ??
      node.value.andThen(visitInterpolation) ??
      super.visitAtRule(node);

  T? visitContentRule(ContentRule node) =>
      visitArgumentInvocation(node.arguments);

  T? visitDebugRule(DebugRule node) => visitExpression(node.expression);

  T? visitDeclaration(Declaration node) =>
      visitInterpolation(node.name) ??
      node.value.andThen(visitExpression) ??
      super.visitDeclaration(node);

  T? visitEachRule(EachRule node) =>
      visitExpression(node.list) ?? super.visitEachRule(node);

  T? visitErrorRule(ErrorRule node) => visitExpression(node.expression);

  T? visitExtendRule(ExtendRule node) => visitInterpolation(node.selector);

  T? visitForRule(ForRule node) =>
      visitExpression(node.from) ??
      visitExpression(node.to) ??
      super.visitForRule(node);

  T? visitForwardRule(ForwardRule node) => node.configuration
      .search((variable) => visitExpression(variable.expression));

  T? visitIfRule(IfRule node) =>
      node.clauses.search((clause) =>
          visitExpression(clause.expression) ??
          clause.children.search((child) => child.accept(this))) ??
      node.lastClause.andThen((lastClause) =>
          lastClause.children.search((child) => child.accept(this)));

  T? visitImportRule(ImportRule node) =>
      node.imports.search((import) => import is StaticImport
          ? visitInterpolation(import.url) ??
              import.modifiers.andThen(visitInterpolation)
          : null);

  T? visitIncludeRule(IncludeRule node) =>
      visitArgumentInvocation(node.arguments) ?? super.visitIncludeRule(node);

  T? visitLoudComment(LoudComment node) => visitInterpolation(node.text);

  T? visitMediaRule(MediaRule node) =>
      visitInterpolation(node.query) ?? super.visitMediaRule(node);

  T? visitReturnRule(ReturnRule node) => visitExpression(node.expression);

  T? visitStyleRule(StyleRule node) =>
      visitInterpolation(node.selector) ?? super.visitStyleRule(node);

  T? visitSupportsRule(SupportsRule node) =>
      visitSupportsCondition(node.condition) ?? super.visitSupportsRule(node);

  T? visitUseRule(UseRule node) => node.configuration
      .search((variable) => visitExpression(variable.expression));

  T? visitVariableDeclaration(VariableDeclaration node) =>
      visitExpression(node.expression);

  T? visitWarnRule(WarnRule node) => visitExpression(node.expression);

  T? visitWhileRule(WhileRule node) =>
      visitExpression(node.condition) ?? super.visitWhileRule(node);

  T? visitExpression(Expression expression) => expression.accept(this);

  T? visitBinaryOperationExpression(BinaryOperationExpression node) =>
      node.left.accept(this) ?? node.right.accept(this);

  T? visitBooleanExpression(BooleanExpression node) => null;

  T? visitColorExpression(ColorExpression node) => null;

  T? visitFunctionExpression(FunctionExpression node) =>
      visitArgumentInvocation(node.arguments);

  T? visitInterpolatedFunctionExpression(InterpolatedFunctionExpression node) =>
      visitInterpolation(node.name) ?? visitArgumentInvocation(node.arguments);

  T? visitIfExpression(IfExpression node) =>
      visitArgumentInvocation(node.arguments);

  T? visitListExpression(ListExpression node) =>
      node.contents.search((item) => item.accept(this));

  T? visitMapExpression(MapExpression node) =>
      node.pairs.search((pair) => pair.$1.accept(this) ?? pair.$2.accept(this));

  T? visitNullExpression(NullExpression node) => null;

  T? visitNumberExpression(NumberExpression node) => null;

  T? visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  T? visitSelectorExpression(SelectorExpression node) => null;

  T? visitStringExpression(StringExpression node) =>
      visitInterpolation(node.text);

  T? visitSupportsExpression(SupportsExpression node) =>
      visitSupportsCondition(node.condition);

  T? visitUnaryOperationExpression(UnaryOperationExpression node) =>
      node.operand.accept(this);

  T? visitValueExpression(ValueExpression node) => null;

  T? visitVariableExpression(VariableExpression node) => null;

  @protected
  T? visitCallableDeclaration(CallableDeclaration node) =>
      node.arguments.arguments.search(
          (argument) => argument.defaultValue.andThen(visitExpression)) ??
      super.visitCallableDeclaration(node);

  /// Visits each expression in an [invocation].
  ///
  /// The default implementation of the visit methods calls this to visit any
  /// argument invocation in a statement.
  @protected
  T? visitArgumentInvocation(ArgumentInvocation invocation) =>
      invocation.positional
          .search((expression) => visitExpression(expression)) ??
      invocation.named.values
          .search((expression) => visitExpression(expression)) ??
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
        _ => null
      };

  /// Visits each expression in an [interpolation].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// interpolation in a statement.
  @protected
  T? visitInterpolation(Interpolation interpolation) => interpolation.contents
      .search((node) => node is Expression ? visitExpression(node) : null);
}
