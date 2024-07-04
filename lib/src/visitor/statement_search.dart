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
  T? visitAtRootRule(AtRootRule node) => visitChildren(node.children);

  T? visitAtRule(AtRule node) => node.children.andThen(visitChildren);

  T? visitContentBlock(ContentBlock node) => visitCallableDeclaration(node);

  T? visitContentRule(ContentRule node) => null;

  T? visitDebugRule(DebugRule node) => null;

  T? visitDeclaration(Declaration node) => node.children.andThen(visitChildren);

  T? visitEachRule(EachRule node) => visitChildren(node.children);

  T? visitErrorRule(ErrorRule node) => null;

  T? visitExtendRule(ExtendRule node) => null;

  T? visitForRule(ForRule node) => visitChildren(node.children);

  T? visitForwardRule(ForwardRule node) => null;

  T? visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  T? visitIfRule(IfRule node) =>
      node.clauses.search(
          (clause) => clause.children.search((child) => child.accept(this))) ??
      node.lastClause.andThen((lastClause) =>
          lastClause.children.search((child) => child.accept(this)));

  T? visitImportRule(ImportRule node) => null;

  T? visitIncludeRule(IncludeRule node) =>
      node.content.andThen(visitContentBlock);

  T? visitLoudComment(LoudComment node) => null;

  T? visitMediaRule(MediaRule node) => visitChildren(node.children);

  T? visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  T? visitReturnRule(ReturnRule node) => null;

  T? visitSilentComment(SilentComment node) => null;

  T? visitStyleRule(StyleRule node) => visitChildren(node.children);

  T? visitStylesheet(Stylesheet node) => visitChildren(node.children);

  T? visitSupportsRule(SupportsRule node) => visitChildren(node.children);

  T? visitUseRule(UseRule node) => null;

  T? visitVariableDeclaration(VariableDeclaration node) => null;

  T? visitWarnRule(WarnRule node) => null;

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
