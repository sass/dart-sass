// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import '../util/nullable.dart';
import 'interface/statement.dart';

/// A visitor that recursively traverses each statement in a Sass AST.
///
/// In addition to the methods from [StatementVisitor], this has more general
/// protected methods that can be overridden to add behavior for a wide variety
/// of AST nodes:
///
/// * [visitCallableDeclaration]
/// * [visitChildren]
///
/// {@category Visitor}
mixin RecursiveStatementVisitor implements StatementVisitor<void> {
  @override
  void visitAtRootRule(AtRootRule node) {
    visitChildren(node.children);
  }

  @override
  void visitAtRule(AtRule node) => node.children.andThen(visitChildren);

  @override
  void visitContentBlock(ContentBlock node) => visitCallableDeclaration(node);

  @override
  void visitContentRule(ContentRule node) {}

  @override
  void visitDebugRule(DebugRule node) {}

  @override
  void visitDeclaration(Declaration node) =>
      node.children.andThen(visitChildren);

  @override
  void visitEachRule(EachRule node) => visitChildren(node.children);

  @override
  void visitErrorRule(ErrorRule node) {}

  @override
  void visitExtendRule(ExtendRule node) {}

  @override
  void visitForRule(ForRule node) => visitChildren(node.children);

  @override
  void visitForwardRule(ForwardRule node) {}

  @override
  void visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  @override
  void visitIfRule(IfRule node) {
    for (var clause in node.clauses) {
      for (var child in clause.children) {
        child.accept(this);
      }
    }

    if (node.lastClause case var lastClause?) {
      for (var child in lastClause.children) {
        child.accept(this);
      }
    }
  }

  @override
  void visitImportRule(ImportRule node) {}

  @override
  void visitIncludeRule(IncludeRule node) =>
      node.content.andThen(visitContentBlock);

  @override
  void visitLoudComment(LoudComment node) {}

  @override
  void visitMediaRule(MediaRule node) => visitChildren(node.children);

  @override
  void visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  @override
  void visitReturnRule(ReturnRule node) {}

  @override
  void visitSilentComment(SilentComment node) {}

  @override
  void visitStyleRule(StyleRule node) => visitChildren(node.children);

  @override
  void visitStylesheet(Stylesheet node) => visitChildren(node.children);

  @override
  void visitSupportsRule(SupportsRule node) => visitChildren(node.children);

  @override
  void visitUseRule(UseRule node) {}

  @override
  void visitVariableDeclaration(VariableDeclaration node) {}

  @override
  void visitWarnRule(WarnRule node) {}

  @override
  void visitWhileRule(WhileRule node) => visitChildren(node.children);

  /// Visits each of [node]'s children.
  ///
  /// The default implementations of [visitFunctionRule] and [visitMixinRule]
  /// call this.
  @protected
  void visitCallableDeclaration(CallableDeclaration node) =>
      visitChildren(node.children);

  /// Visits each child in [children].
  ///
  /// The default implementation of the visit methods for all [ParentStatement]s
  /// call this.
  @protected
  void visitChildren(List<Statement> children) {
    for (var child in children) {
      child.accept(this);
    }
  }
}
