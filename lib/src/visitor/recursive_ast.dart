// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../util/nullable.dart';
import '../ast/sass.dart';
import 'interface/expression.dart';
import 'interface/if_condition_expression.dart';
import 'interface/interpolated_selector.dart';
import 'recursive_statement.dart';

/// A visitor that recursively traverses each statement and expression in a Sass
/// AST.
///
/// This extends [RecursiveStatementVisitor] to traverse each expression in
/// addition to each statement. It adds even more protected methods:
///
/// * [visitArgumentList]
/// * [visitSupportsCondition]
/// * [visitInterpolation]
/// * [visitQualifiedname]
///
/// {@category Visitor}
mixin RecursiveAstVisitor on RecursiveStatementVisitor
    implements
        ExpressionVisitor<void>,
        IfConditionExpressionVisitor<void>,
        InterpolatedSelectorVisitor<void> {
  void visitAtRootRule(AtRootRule node) {
    node.query.andThen(visitInterpolation);
    super.visitAtRootRule(node);
  }

  void visitAtRule(AtRule node) {
    visitInterpolation(node.name);
    node.value.andThen(visitInterpolation);
    super.visitAtRule(node);
  }

  void visitContentRule(ContentRule node) {
    visitArgumentList(node.arguments);
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

    if (node.lastClause case var lastClause?) {
      for (var child in lastClause.children) {
        child.accept(this);
      }
    }
  }

  void visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is StaticImport) {
        visitInterpolation(import.url);
        import.modifiers.andThen(visitInterpolation);
      }
    }
  }

  void visitIncludeRule(IncludeRule node) {
    visitArgumentList(node.arguments);
    super.visitIncludeRule(node);
  }

  void visitLoudComment(LoudComment node) {
    visitInterpolation(node.text);
  }

  void visitMediaRule(MediaRule node) {
    visitInterpolation(node.query);
    super.visitMediaRule(node);
  }

  void visitReturnRule(ReturnRule node) {
    visitExpression(node.expression);
  }

  void visitStyleRule(StyleRule node) {
    node.selector.andThen(visitInterpolation);
    super.visitStyleRule(node);
  }

  void visitSupportsRule(SupportsRule node) {
    visitSupportsCondition(node.condition);
    super.visitSupportsRule(node);
  }

  void visitUseRule(UseRule node) {
    for (var variable in node.configuration) {
      visitExpression(variable.expression);
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

  // Expressions

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
      visitExpression(variable.expression);
    }
  }

  void visitFunctionExpression(FunctionExpression node) {
    visitArgumentList(node.arguments);
  }

  void visitIfExpression(IfExpression node) {
    for (var (condition, value) in node.branches) {
      condition?.accept(this);
      value.accept(this);
    }
  }

  void visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) {
    visitInterpolation(node.name);
    visitArgumentList(node.arguments);
  }

  void visitLegacyIfExpression(LegacyIfExpression node) {
    visitArgumentList(node.arguments);
  }

  void visitListExpression(ListExpression node) {
    for (var item in node.contents) {
      item.accept(this);
    }
  }

  void visitMapExpression(MapExpression node) {
    for (var (key, value) in node.pairs) {
      key.accept(this);
      value.accept(this);
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

  void visitSupportsExpression(SupportsExpression node) {
    visitSupportsCondition(node.condition);
  }

  void visitUnaryOperationExpression(UnaryOperationExpression node) {
    node.operand.accept(this);
  }

  void visitValueExpression(ValueExpression node) {}

  void visitVariableExpression(VariableExpression node) {}

  // `if()` condition expressions

  void visitIfConditionParenthesized(IfConditionParenthesized node) {
    node.expression.accept(this);
  }

  void visitIfConditionNegation(IfConditionNegation node) {
    node.expression.accept(this);
  }

  void visitIfConditionOperation(IfConditionOperation node) {
    for (var node in node.expressions) {
      node.accept(this);
    }
  }

  void visitIfConditionFunction(IfConditionFunction node) {
    visitInterpolation(node.name);
    visitInterpolation(node.arguments);
  }

  void visitIfConditionSass(IfConditionSass node) {
    node.expression.accept(this);
  }

  void visitIfConditionRaw(IfConditionRaw node) {
    visitInterpolation(node.text);
  }

  // Interpolated selectors

  void visitAttributeSelector(InterpolatedAttributeSelector node) {
    visitQualifiedName(node.name);
    node.value.andThen(visitInterpolation);
    node.modifier.andThen(visitInterpolation);
  }

  void visitClassSelector(InterpolatedClassSelector node) {
    visitInterpolation(node.name);
  }

  void visitComplexSelector(InterpolatedComplexSelector node) {
    for (var component in node.components) {
      visitCompoundSelector(component.selector);
    }
  }

  void visitCompoundSelector(InterpolatedCompoundSelector node) {
    for (var simple in node.components) {
      simple.accept(this);
    }
  }

  void visitIDSelector(InterpolatedIDSelector node) {
    visitInterpolation(node.name);
  }

  void visitParentSelector(InterpolatedParentSelector node) {
    node.suffix.andThen(visitInterpolation);
  }

  void visitPlaceholderSelector(InterpolatedPlaceholderSelector node) {
    visitInterpolation(node.name);
  }

  void visitPseudoSelector(InterpolatedPseudoSelector node) {
    visitInterpolation(node.name);
    node.argument.andThen(visitInterpolation);
    node.selector.andThen(visitSelectorList);
  }

  void visitSelectorList(InterpolatedSelectorList node) {
    for (var component in node.components) {
      visitComplexSelector(component);
    }
  }

  void visitTypeSelector(InterpolatedTypeSelector node) {
    visitQualifiedName(node.name);
  }

  void visitUniversalSelector(InterpolatedUniversalSelector node) {
    node.namespace.andThen(visitInterpolation);
  }

  @protected
  void visitCallableDeclaration(CallableDeclaration node) {
    for (var parameter in node.parameters.parameters) {
      parameter.defaultValue.andThen(visitExpression);
    }
    super.visitCallableDeclaration(node);
  }

  /// Visits each expression in an [invocation].
  ///
  /// The default implementation of the visit methods calls this to visit any
  /// argument invocation in a statement.
  @protected
  void visitArgumentList(ArgumentList invocation) {
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
    switch (condition) {
      case SupportsOperation():
        visitSupportsCondition(condition.left);
        visitSupportsCondition(condition.right);
      case SupportsNegation():
        visitSupportsCondition(condition.condition);
      case SupportsInterpolation():
        visitExpression(condition.expression);
      case SupportsDeclaration():
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

  /// Visits each interpolatoin in [node].
  ///
  /// The default implementation of the visit methods calls this to visit any
  /// qualified names in a selector.
  @protected
  void visitQualifiedName(InterpolatedQualifiedName node) {
    node.namespace.andThen(visitInterpolation);
    visitInterpolation(node.name);
  }
}
