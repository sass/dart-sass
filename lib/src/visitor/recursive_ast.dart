// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../util/nullable.dart';
import '../ast/sass.dart';
import 'interface/expression.dart';
import 'recursive_statement.dart';

/// A visitor that recursively traverses each statement and expression in a Sass
/// AST.
///
/// This extends [RecursiveStatementVisitor] to traverse each expression in
/// addition to each statement. It adds even more protected methods:
///
/// * [visitArgumentInvocation]
/// * [visitSupportsCondition]
/// * [visitInterpolation]
///
/// {@category Visitor}
abstract class RecursiveAstVisitor extends RecursiveStatementVisitor
    implements ExpressionVisitor<void> {
  const RecursiveAstVisitor();

  void visitAtRootRule(AtRootRule node) {
    node.query.andThen(visitInterpolation);
    super.visitAtRootRule(node);
  }

  void visitAtRule(AtRule node) {
    visitInterpolation(node.name);
    node.value.andThen(visitInterpolation);
    super.visitAtRule(node);
  }

  void visitCalculationExpression(CalculationExpression node) {
    for (var argument in node.arguments) {
      argument.accept(this);
    }
  }

  void visitContentRule(ContentRule node) {
    visitArgumentInvocation(node.arguments);
  }

  void visitDebugRule(DebugRule node) {
    visitExpression(node.expression);
  }

  void visitDeclaration(Declaration node) {
    visitInterpolation(node.name);
    node.value.andThen(visitExpression);
    super.visitDeclaration(node);
  }

  void visitEachRule(EachRule node) {
    visitExpression(node.list);
    super.visitEachRule(node);
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
    super.visitForRule(node);
  }

  void visitIfRule(IfRule node) {
    for (var clause in node.clauses) {
      visitExpression(clause.expression);
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

  void visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is StaticImport) {
        visitInterpolation(import.url);
        import.supports.andThen(visitSupportsCondition);
        import.media.andThen(visitInterpolation);
      }
    }
  }

  void visitIncludeRule(IncludeRule node) {
    visitArgumentInvocation(node.arguments);
    super.visitIncludeRule(node);
  }

  void visitLoudComment(LoudComment node) {
    visitInterpolation(node.text);
  }

  void visitMediaRule(MediaRule node) {
    visitInterpolation(node.query);
    super.visitMediaRule(node);
  }

  void visitMixinRule(MixinRule node) => visitCallableDeclaration(node);

  void visitReturnRule(ReturnRule node) {
    visitExpression(node.expression);
  }

  void visitStyleRule(StyleRule node) {
    visitInterpolation(node.selector);
    super.visitStyleRule(node);
  }

  void visitSupportsRule(SupportsRule node) {
    visitSupportsCondition(node.condition);
    super.visitSupportsRule(node);
  }

  void visitUseRule(UseRule node) {
    for (var variable in node.configuration) {
      variable.expression.accept(this);
    }
  }

  void visitVariableDeclaration(VariableDeclaration node) {
    visitExpression(node.expression);
  }

  void visitWarnRule(WarnRule node) {
    visitExpression(node.expression);
  }

  void visitWhileRule(WhileRule node) {
    visitExpression(node.condition);
    super.visitWhileRule(node);
  }

  void visitExpression(Expression expression) {
    expression.accept(this);
  }

  void visitBinaryOperationExpression(BinaryOperationExpression node) {
    node.left.accept(this);
    node.right.accept(this);
  }

  void visitBooleanExpression(BooleanExpression node) {}

  void visitColorExpression(ColorExpression node) {}

  void visitForwardRule(ForwardRule node) {
    for (var variable in node.configuration) {
      variable.expression.accept(this);
    }
  }

  void visitFunctionExpression(FunctionExpression node) {
    visitArgumentInvocation(node.arguments);
  }

  void visitInterpolatedFunctionExpression(
      InterpolatedFunctionExpression node) {
    visitInterpolation(node.name);
    visitArgumentInvocation(node.arguments);
  }

  void visitIfExpression(IfExpression node) {
    visitArgumentInvocation(node.arguments);
  }

  void visitListExpression(ListExpression node) {
    for (var item in node.contents) {
      item.accept(this);
    }
  }

  void visitMapExpression(MapExpression node) {
    for (var pair in node.pairs) {
      pair.item1.accept(this);
      pair.item2.accept(this);
    }
  }

  void visitNullExpression(NullExpression node) {}

  void visitNumberExpression(NumberExpression node) {}

  void visitParenthesizedExpression(ParenthesizedExpression node) {
    node.expression.accept(this);
  }

  void visitSelectorExpression(SelectorExpression node) {}

  void visitStringExpression(StringExpression node) {
    visitInterpolation(node.text);
  }

  void visitUnaryOperationExpression(UnaryOperationExpression node) {
    node.operand.accept(this);
  }

  void visitValueExpression(ValueExpression node) {}

  void visitVariableExpression(VariableExpression node) {}

  @protected
  void visitCallableDeclaration(CallableDeclaration node) {
    for (var argument in node.arguments.arguments) {
      argument.defaultValue.andThen(visitExpression);
    }
    super.visitCallableDeclaration(node);
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
    invocation.rest.andThen(visitExpression);
    invocation.keywordRest.andThen(visitExpression);
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
}
