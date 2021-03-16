// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import 'interface/statement.dart';

/// A visitor that recursively traverses each statement in a Sass AST.
///
/// In addition to the methods from [StatementVisitor], this has more general
/// protected methods that can be overridden to add behavior for a wide variety
/// of AST nodes:
///
/// * [visitCallableDeclaration]
/// * [visitArgumentInvocation]
/// * [visitSupportsCondition]
/// * [visitChildren]
/// * [visitInterpolation]
/// * [visitExpression]
abstract class RecursiveStatementVisitor implements StatementVisitor<void> {
  void visitAtRootRule(AtRootRule node) {
    if (node.query != null) visitInterpolation(node.query);
    visitChildren(node);
  }

  void visitAtRule(AtRule node) {
    visitInterpolation(node.name);
    if (node.value != null) visitInterpolation(node.value);
    if (node.children != null) visitChildren(node);
  }

  void visitContentBlock(ContentBlock node) => visitCallableDeclaration(node);

  void visitContentRule(ContentRule node) {
    visitArgumentInvocation(node.arguments);
  }

  void visitDebugRule(DebugRule node) {
    visitExpression(node.expression);
  }

  void visitDeclaration(Declaration node) {
    visitInterpolation(node.name);
    if (node.value != null) visitExpression(node.value);
    if (node.children != null) visitChildren(node);
  }

  void visitEachRule(EachRule node) {
    visitExpression(node.list);
    visitChildren(node);
  }

  void visitErrorRule(ErrorRule node) {
    visitExpression(node.expression);
  }

  void visitExtendRule(ExtendRule node) {
    visitInterpolation(node.selector);
  }

  void visitForRule(ForRule node) {
    visitExpression(node.from);
    visitExpression(node.to);
    visitChildren(node);
  }

  void visitForwardRule(ForwardRule node) {}

  void visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  void visitIfRule(IfRule node) {
    for (var clause in node.clauses) {
      visitExpression(clause.expression);
      for (var child in clause.children) {
        child.accept(this);
      }
    }

    if (node.lastClause != null) {
      for (var child in node.lastClause.children) {
        child.accept(this);
      }
    }
  }

  void visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is StaticImport) {
        visitInterpolation(import.url);
        if (import.supports != null) visitSupportsCondition(import.supports);
        if (import.media != null) visitInterpolation(import.media);
      }
    }
  }

  void visitIncludeRule(IncludeRule node) {
    visitArgumentInvocation(node.arguments);
    if (node.content != null) visitContentBlock(node.content);
  }

  void visitLoudComment(LoudComment node) {
    visitInterpolation(node.text);
  }

  void visitMediaRule(MediaRule node) {
    visitInterpolation(node.query);
    visitChildren(node);
  }

  void visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  void visitReturnRule(ReturnRule node) {
    visitExpression(node.expression);
  }

  void visitSilentComment(SilentComment node) {}

  void visitStyleRule(StyleRule node) {
    visitInterpolation(node.selector);
    visitChildren(node);
  }

  void visitStylesheet(Stylesheet node) => visitChildren(node);

  void visitSupportsRule(SupportsRule node) {
    visitSupportsCondition(node.condition);
    visitChildren(node);
  }

  void visitUseRule(UseRule node) {}

  void visitVariableDeclaration(VariableDeclaration node) {
    visitExpression(node.expression);
  }

  void visitWarnRule(WarnRule node) {
    visitExpression(node.expression);
  }

  void visitWhileRule(WhileRule node) {
    visitExpression(node.condition);
    visitChildren(node);
  }

  /// Visits each of [node]'s expressions and children.
  ///
  /// The default implementations of [visitFunctionRule] and [visitMixinRule]
  /// call this.
  @protected
  void visitCallableDeclaration(CallableDeclaration node) {
    for (var argument in node.arguments.arguments) {
      if (argument.defaultValue != null) visitExpression(argument.defaultValue);
    }
    visitChildren(node);
  }

  /// Visits each expression in an [invocation].
  ///
  /// The default implementation of the visit methods calls this to visit any
  /// argument invocation in a statement.
  @protected
  void visitArgumentInvocation(ArgumentInvocation invocation) {
    for (var expression in invocation.positional) {
      visitExpression(expression);
    }
    for (var expression in invocation.named.values) {
      visitExpression(expression);
    }
    if (invocation.rest != null) {
      visitExpression(invocation.rest);
    }
    if (invocation.keywordRest != null) {
      visitExpression(invocation.keywordRest);
    }
  }

  /// Visits each expression in [condition].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// [SupportsCondition] they encounter.
  @protected
  void visitSupportsCondition(SupportsCondition condition) {
    if (condition is SupportsOperation) {
      visitSupportsCondition(condition.left);
      visitSupportsCondition(condition.right);
    } else if (condition is SupportsNegation) {
      visitSupportsCondition(condition.condition);
    } else if (condition is SupportsInterpolation) {
      visitExpression(condition.expression);
    } else if (condition is SupportsDeclaration) {
      visitExpression(condition.name);
      visitExpression(condition.value);
    }
  }

  /// Visits each of [node]'s children.
  ///
  /// The default implementation of the visit methods for all [ParentStatement]s
  /// call this.
  @protected
  void visitChildren(ParentStatement node) {
    for (var child in node.children) {
      child.accept(this);
    }
  }

  /// Visits each expression in an [interpolation].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// interpolation in a statement.
  @protected
  void visitInterpolation(Interpolation interpolation) {
    for (var node in interpolation.contents) {
      if (node is Expression) visitExpression(node);
    }
  }

  /// Visits [expression].
  ///
  /// The default implementation of the visit methods call this to visit any
  /// expression in a statement.
  @protected
  void visitExpression(Expression expression) {}
}
