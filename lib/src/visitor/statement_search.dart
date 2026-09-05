// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import '../util/iterable.dart';
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
mixin StatementSearchVisitor<T> implements StatementVisitor<T?> {
  @override
  T? visitAtRootRule(AtRootRule node) => visitChildren(node.children);

  @override
  T? visitAtRule(AtRule node) => node.children.andThen(visitChildren);

  @override
  T? visitContentBlock(ContentBlock node) => visitCallableDeclaration(node);

  @override
  T? visitContentRule(ContentRule node) => null;

  @override
  T? visitDebugRule(DebugRule node) => null;

  @override
  T? visitDeclaration(Declaration node) => node.children.andThen(visitChildren);

  @override
  T? visitEachRule(EachRule node) => visitChildren(node.children);

  @override
  T? visitErrorRule(ErrorRule node) => null;

  @override
  T? visitExtendRule(ExtendRule node) => null;

  @override
  T? visitForRule(ForRule node) => visitChildren(node.children);

  @override
  T? visitForwardRule(ForwardRule node) => null;

  @override
  T? visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  @override
  T? visitIfRule(IfRule node) =>
      node.clauses.search(
        (clause) => clause.children.search((child) => child.accept(this)),
      ) ??
      node.lastClause.andThen(
        (lastClause) =>
            lastClause.children.search((child) => child.accept(this)),
      );

  @override
  T? visitImportRule(ImportRule node) => null;

  @override
  T? visitIncludeRule(IncludeRule node) =>
      node.content.andThen(visitContentBlock);

  @override
  T? visitLoudComment(LoudComment node) => null;

  @override
  T? visitMediaRule(MediaRule node) => visitChildren(node.children);

  @override
  T? visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  @override
  T? visitReturnRule(ReturnRule node) => null;

  @override
  T? visitSilentComment(SilentComment node) => null;

  @override
  T? visitStyleRule(StyleRule node) => visitChildren(node.children);

  @override
  T? visitStylesheet(Stylesheet node) => visitChildren(node.children);

  @override
  T? visitSupportsRule(SupportsRule node) => visitChildren(node.children);

  @override
  T? visitUseRule(UseRule node) => null;

  @override
  T? visitVariableDeclaration(VariableDeclaration node) => null;

  @override
  T? visitWarnRule(WarnRule node) => null;

  @override
  T? visitWhileRule(WhileRule node) => visitChildren(node.children);

  /// Visits each of [node]'s expressions and children.
  ///
  /// The default implementations of [visitFunctionRule] and [visitMixinRule]
  /// call this.
  @protected
  T? visitCallableDeclaration(CallableDeclaration node) =>
      visitChildren(node.children);

  /// Visits each child in [children].
  ///
  /// The default implementation of the visit methods for all [ParentStatement]s
  /// call this.
  @protected
  T? visitChildren(List<Statement> children) =>
      children.search((child) => child.accept(this));
}
