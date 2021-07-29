// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import '../util/nullable.dart';
import 'interface/statement.dart';
import 'recursive_statement.dart';

/// A [StatementVisitor] whose `visit*` methods default to returning `null`, but
/// which returns the first non-`null` value returned by any method.
///
/// This can be extended to find the first instance of particular nodes in the
/// AST.
///
/// This supports the same additional methods as [RecursiveStatementVisitor].
///
/// {@category Visitor}
abstract class StatementSearchVisitor<T> implements StatementVisitor<T?> {
  const StatementSearchVisitor();

  T? visitAtRootRule(AtRootRule node) =>
      node.query.andThen(visitInterpolation) ?? visitChildren(node.children);

  T? visitAtRule(AtRule node) =>
      visitInterpolation(node.name) ??
      node.value.andThen(visitInterpolation) ??
      node.children.andThen(visitChildren);

  T? visitContentBlock(ContentBlock node) => visitCallableDeclaration(node);

  T? visitContentRule(ContentRule node) =>
      visitArgumentInvocation(node.arguments);

  T? visitDebugRule(DebugRule node) => visitExpression(node.expression);

  T? visitDeclaration(Declaration node) =>
      visitInterpolation(node.name) ??
      node.value.andThen(visitExpression) ??
      node.children.andThen(visitChildren);

  T? visitEachRule(EachRule node) =>
      visitExpression(node.list) ?? visitChildren(node.children);

  T? visitErrorRule(ErrorRule node) => visitExpression(node.expression);

  T? visitExtendRule(ExtendRule node) => visitInterpolation(node.selector);

  T? visitForRule(ForRule node) =>
      visitExpression(node.from) ??
      visitExpression(node.to) ??
      visitChildren(node.children);

  T? visitForwardRule(ForwardRule node) => null;

  T? visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  T? visitIfRule(IfRule node) =>
      node.clauses._search((clause) =>
          visitExpression(clause.expression) ??
          clause.children._search((child) => child.accept(this))) ??
      node.lastClause.andThen((lastClause) =>
          lastClause.children._search((child) => child.accept(this)));

  T? visitImportRule(ImportRule node) => node.imports._search((import) {
        if (import is StaticImport) {
          return visitInterpolation(import.url) ??
              import.supports.andThen(visitSupportsCondition) ??
              import.media.andThen(visitInterpolation);
        }
      });

  T? visitIncludeRule(IncludeRule node) =>
      visitArgumentInvocation(node.arguments) ??
      node.content.andThen(visitContentBlock);

  T? visitLoudComment(LoudComment node) => visitInterpolation(node.text);

  T? visitMediaRule(MediaRule node) =>
      visitInterpolation(node.query) ?? visitChildren(node.children);

  T? visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  T? visitReturnRule(ReturnRule node) => visitExpression(node.expression);

  T? visitSilentComment(SilentComment node) => null;

  T? visitStyleRule(StyleRule node) =>
      visitInterpolation(node.selector) ?? visitChildren(node.children);

  T? visitStylesheet(Stylesheet node) => visitChildren(node.children);

  T? visitSupportsRule(SupportsRule node) =>
      visitSupportsCondition(node.condition) ?? visitChildren(node.children);

  T? visitUseRule(UseRule node) => null;

  T? visitVariableDeclaration(VariableDeclaration node) =>
      visitExpression(node.expression);

  T? visitWarnRule(WarnRule node) => visitExpression(node.expression);

  T? visitWhileRule(WhileRule node) =>
      visitExpression(node.condition) ?? visitChildren(node.children);

  /// Visits each of [node]'s expressions and children.
  ///
  /// The default implementations of [visitFunctionRule] and [visitMixinRule]
  /// call this.
  @protected
  T? visitCallableDeclaration(CallableDeclaration node) =>
      node.arguments.arguments._search(
          (argument) => argument.defaultValue.andThen(visitExpression)) ??
      visitChildren(node.children);

  /// Visits each expression in an [invocation].
  ///
  /// The default implementation of the visit methods calls this to visit any
  /// argument invocation in a statement.
  @protected
  T? visitArgumentInvocation(ArgumentInvocation invocation) =>
      invocation.positional
          ._search((expression) => visitExpression(expression)) ??
      invocation.named.values
          ._search((expression) => visitExpression(expression)) ??
      invocation.rest.andThen(visitExpression) ??
      invocation.keywordRest.andThen(visitExpression);

  /// Visits each expression in [condition].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// [SupportsCondition] they encounter.
  @protected
  T? visitSupportsCondition(SupportsCondition condition) {
    if (condition is SupportsOperation) {
      return visitSupportsCondition(condition.left) ??
          visitSupportsCondition(condition.right);
    } else if (condition is SupportsNegation) {
      return visitSupportsCondition(condition.condition);
    } else if (condition is SupportsInterpolation) {
      return visitExpression(condition.expression);
    } else if (condition is SupportsDeclaration) {
      return visitExpression(condition.name) ??
          visitExpression(condition.value);
    } else {
      return null;
    }
  }

  /// Visits each child in [children].
  ///
  /// The default implementation of the visit methods for all [ParentStatement]s
  /// call this.
  @protected
  T? visitChildren(List<Statement> children) =>
      children._search((child) => child.accept(this));

  /// Visits each expression in an [interpolation].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// interpolation in a statement.
  @protected
  T? visitInterpolation(Interpolation interpolation) => interpolation.contents
      ._search((node) => node is Expression ? visitExpression(node) : null);

  /// Visits [expression].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// expression in a statement.
  @protected
  T? visitExpression(Expression expression) => null;
}

extension _IterableExtension<E> on Iterable<E> {
  /// Returns the first `T` returned by [callback] for an element of [iterable],
  /// or `null` if it returns `null` for every element.
  T? _search<T>(T? Function(E element) callback) {
    for (var element in this) {
      var value = callback(element);
      if (value != null) return value;
    }
  }
}
