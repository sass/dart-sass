// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/sass.dart';
import 'interface/statement.dart';

/// A visitor that recursively traverses each statement in a Sass AST.
///
/// In addition to the methods from [StatementVisitor], this has more general
/// protected methods that can be overriden to add behavior for a wide variety
/// of AST nodes:
///
/// * [visitCallableDeclaration]
/// * [visitSupportsCondition]
/// * [visitChildren]
/// * [visitInterpolation]
/// * [visitExpression]
///
/// The default implementation of the visit methods all return `null`.
abstract class RecursiveStatementVisitor<T> implements StatementVisitor<T> {
  T visitAtRootRule(AtRootRule node) {
    visitInterpolation(node.query);
    return visitChildren(node);
  }

  T visitAtRule(AtRule node) {
    visitInterpolation(node.value);
    return node.children == null ? null : visitChildren(node);
  }

  T visitContentRule(ContentRule node) => null;

  T visitDebugRule(DebugRule node) {
    visitExpression(node.expression);
    return null;
  }

  T visitDeclaration(Declaration node) {
    visitInterpolation(node.name);
    visitExpression(node.value);
    return node.children == null ? null : visitChildren(node);
  }

  T visitEachRule(EachRule node) {
    visitExpression(node.list);
    return visitChildren(node);
  }

  T visitErrorRule(ErrorRule node) {
    visitExpression(node.expression);
    return null;
  }

  T visitExtendRule(ExtendRule node) {
    visitInterpolation(node.selector);
    return null;
  }

  T visitForRule(ForRule node) {
    visitExpression(node.from);
    visitExpression(node.to);
    return visitChildren(node);
  }

  T visitFunctionRule(FunctionRule node) => visitCallableDeclaration(node);

  T visitIfRule(IfRule node) {
    for (var clause in node.clauses) {
      _visitIfClause(clause);
    }
    if (node.lastClause != null) _visitIfClause(node.lastClause);
    return null;
  }

  /// Visits [clause]'s expression and children.
  void _visitIfClause(IfClause clause) {
    if (clause.expression != null) visitExpression(clause.expression);
    for (var child in clause.children) {
      child.accept(this);
    }
  }

  T visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is StaticImport) {
        visitInterpolation(import.url);
        if (import.supports != null) visitSupportsCondition(import.supports);
        if (import.media != null) visitInterpolation(import.media);
      }
    }
    return null;
  }

  T visitIncludeRule(IncludeRule node) {
    for (var expression in node.arguments.positional) {
      visitExpression(expression);
    }
    for (var expression in node.arguments.named.values) {
      visitExpression(expression);
    }
    if (node.arguments.rest != null) {
      visitExpression(node.arguments.rest);
    }
    if (node.arguments.keywordRest != null) {
      visitExpression(node.arguments.keywordRest);
    }

    return node.children == null ? null : visitChildren(node);
  }

  T visitLoudComment(LoudComment node) {
    visitInterpolation(node.text);
    return null;
  }

  T visitMediaRule(MediaRule node) {
    visitInterpolation(node.query);
    return visitChildren(node);
  }

  T visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  T visitReturnRule(ReturnRule node) {
    visitExpression(node.expression);
    return null;
  }

  T visitSilentComment(SilentComment node) => null;

  T visitStyleRule(StyleRule node) {
    visitInterpolation(node.selector);
    return visitChildren(node);
  }

  T visitStylesheet(Stylesheet node) => visitChildren(node);

  T visitSupportsRule(SupportsRule node) {
    visitSupportsCondition(node.condition);
    return visitChildren(node);
  }

  T visitVariableDeclaration(VariableDeclaration node) {
    visitExpression(node.expression);
    return null;
  }

  T visitWarnRule(WarnRule node) {
    visitExpression(node.expression);
    return null;
  }

  T visitWhileRule(WhileRule node) {
    visitExpression(node.condition);
    return visitChildren(node);
  }

  /// Visits each of [node]'s expressions and children.
  ///
  /// The default implementations of [visitFunctionRule] and [visitMixinRule]
  /// call this.
  @protected
  T visitCallableDeclaration(CallableDeclaration node) {
    for (var argument in node.arguments.arguments) {
      if (argument.defaultValue != null) visitExpression(argument.defaultValue);
    }
    return visitChildren(node);
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
  /// call this and return its result.
  @protected
  T visitChildren(ParentStatement node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
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
