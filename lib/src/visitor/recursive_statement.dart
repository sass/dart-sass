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
abstract class RecursiveStatementVisitor implements StatementVisitor<void> {
  const RecursiveStatementVisitor();

  void visitAtRootRule(AtRootRule node) {
    visitChildren(node.children);
  }

  void visitAtRule(AtRule node) => node.children.andThen(visitChildren);

  void visitContentBlock(ContentBlock node) => visitCallableDeclaration(node);

  void visitContentRule(ContentRule node) {}

  void visitDebugRule(DebugRule node) {}

  void visitDeclaration(Declaration node) =>
      node.children.andThen(visitChildren);

  void visitEachRule(EachRule node) => visitChildren(node.children);

  void visitErrorRule(ErrorRule node) {}

  void visitExtendRule(ExtendRule node) {}

  void visitForRule(ForRule node) => visitChildren(node.children);

  void visitForwardRule(ForwardRule node) {}

  void visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  void visitIfRule(IfRule node) {
    for (var clause in node.clauses) {
      for (var child in clause.children) {
        child.accept(this);
      }
    }

    node.lastClause.andThen((lastClause) {
      for (var child in lastClause.children) {
        child.accept(this);
      }
    });
  }

  void visitImportRule(ImportRule node) {}

  void visitIncludeRule(IncludeRule node) =>
      node.content.andThen(visitContentBlock);

  void visitLoudComment(LoudComment node) {}

  void visitMediaRule(MediaRule node) => visitChildren(node.children);

  void visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  void visitReturnRule(ReturnRule node) {}

  void visitSilentComment(SilentComment node) {}

  void visitStyleRule(StyleRule node) => visitChildren(node.children);

  void visitStylesheet(Stylesheet node) => visitChildren(node.children);

  void visitSupportsRule(SupportsRule node) => visitChildren(node.children);

  void visitUseRule(UseRule node) {}

  void visitVariableDeclaration(VariableDeclaration node) {}

  void visitWarnRule(WarnRule node) {}

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
