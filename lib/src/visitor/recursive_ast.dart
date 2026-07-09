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
  @override
  void visitAtRootRule(AtRootRule node) {
    node.query.andThen(visitInterpolation);
    super.visitAtRootRule(node);
  }

  @override
  void visitAtRule(AtRule node) {
    visitInterpolation(node.name);
    node.value.andThen(visitInterpolation);
    super.visitAtRule(node);
  }

  @override
  void visitContentRule(ContentRule node) {
    visitArgumentList(node.arguments);
  }

  @override
  void visitDebugRule(DebugRule node) {
    visitExpression(node.expression);
  }

  @override
  void visitDeclaration(Declaration node) {
    visitInterpolation(node.name);
    node.value.andThen(visitExpression);
    super.visitDeclaration(node);
  }

  @override
  void visitEachRule(EachRule node) {
    visitExpression(node.list);
    super.visitEachRule(node);
  }

  @override
  void visitErrorRule(ErrorRule node) {
    visitExpression(node.expression);
  }

  @override
  void visitExtendRule(ExtendRule node) {
    visitInterpolation(node.selector);
  }

  @override
  void visitForRule(ForRule node) {
    visitExpression(node.from);
    visitExpression(node.to);
    super.visitForRule(node);
  }

  @override
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

  @override
  void visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is StaticImport) {
        visitInterpolation(import.url);
        import.modifiers.andThen(visitInterpolation);
      }
    }
  }

  @override
  void visitIncludeRule(IncludeRule node) {
    visitArgumentList(node.arguments);
    super.visitIncludeRule(node);
  }

  @override
  void visitLoudComment(LoudComment node) {
    visitInterpolation(node.text);
  }

  @override
  void visitMediaRule(MediaRule node) {
    visitInterpolation(node.query);
    super.visitMediaRule(node);
  }

  @override
  void visitReturnRule(ReturnRule node) {
    visitExpression(node.expression);
  }

  @override
  void visitStyleRule(StyleRule node) {
    node.selector.andThen(visitInterpolation);
    super.visitStyleRule(node);
  }

  @override
  void visitSupportsRule(SupportsRule node) {
    visitSupportsCondition(node.condition);
    super.visitSupportsRule(node);
  }

  @override
  void visitUseRule(UseRule node) {
    for (var variable in node.configuration) {
      visitExpression(variable.expression);
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    visitExpression(node.expression);
  }

  @override
  void visitWarnRule(WarnRule node) {
    visitExpression(node.expression);
  }

  @override
  void visitWhileRule(WhileRule node) {
    visitExpression(node.condition);
    super.visitWhileRule(node);
  }

  // Expressions

  void visitExpression(Expression expression) {
    expression.accept(this);
  }

  @override
  void visitBinaryOperationExpression(BinaryOperationExpression node) {
    node.left.accept(this);
    node.right.accept(this);
  }

  @override
  void visitBooleanExpression(BooleanExpression node) {}

  @override
  void visitColorExpression(ColorExpression node) {}

  @override
  void visitForwardRule(ForwardRule node) {
    for (var variable in node.configuration) {
      visitExpression(variable.expression);
    }
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    visitArgumentList(node.arguments);
  }

  @override
  void visitIfExpression(IfExpression node) {
    for (var (condition, value) in node.branches) {
      condition?.accept(this);
      value.accept(this);
    }
  }

  @override
  void visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) {
    visitInterpolation(node.name);
    visitArgumentList(node.arguments);
  }

  @override
  void visitLegacyIfExpression(LegacyIfExpression node) {
    visitArgumentList(node.arguments);
  }

  @override
  void visitListExpression(ListExpression node) {
    for (var item in node.contents) {
      item.accept(this);
    }
  }

  @override
  void visitMapExpression(MapExpression node) {
    for (var (key, value) in node.pairs) {
      key.accept(this);
      value.accept(this);
    }
  }

  @override
  void visitNullExpression(NullExpression node) {}

  @override
  void visitNumberExpression(NumberExpression node) {}

  @override
  void visitParenthesizedExpression(ParenthesizedExpression node) {
    node.expression.accept(this);
  }

  @override
  void visitSelectorExpression(SelectorExpression node) {}

  @override
  void visitStringExpression(StringExpression node) {
    visitInterpolation(node.text);
  }

  @override
  void visitSupportsExpression(SupportsExpression node) {
    visitSupportsCondition(node.condition);
  }

  @override
  void visitUnaryOperationExpression(UnaryOperationExpression node) {
    node.operand.accept(this);
  }

  @override
  void visitValueExpression(ValueExpression node) {}

  @override
  void visitVariableExpression(VariableExpression node) {}

  // `if()` condition expressions

  @override
  void visitIfConditionParenthesized(IfConditionParenthesized node) {
    node.expression.accept(this);
  }

  @override
  void visitIfConditionNegation(IfConditionNegation node) {
    node.expression.accept(this);
  }

  @override
  void visitIfConditionOperation(IfConditionOperation node) {
    for (var node in node.expressions) {
      node.accept(this);
    }
  }

  @override
  void visitIfConditionFunction(IfConditionFunction node) {
    visitInterpolation(node.name);
    visitInterpolation(node.arguments);
  }

  @override
  void visitIfConditionSass(IfConditionSass node) {
    node.expression.accept(this);
  }

  @override
  void visitIfConditionRaw(IfConditionRaw node) {
    visitInterpolation(node.text);
  }

  // Interpolated selectors

  @override
  void visitAttributeSelector(InterpolatedAttributeSelector node) {
    visitQualifiedName(node.name);
    node.value.andThen(visitInterpolation);
    node.modifier.andThen(visitInterpolation);
  }

  @override
  void visitClassSelector(InterpolatedClassSelector node) {
    visitInterpolation(node.name);
  }

  @override
  void visitComplexSelector(InterpolatedComplexSelector node) {
    for (var component in node.components) {
      visitCompoundSelector(component.selector);
    }
  }

  @override
  void visitCompoundSelector(InterpolatedCompoundSelector node) {
    for (var simple in node.components) {
      simple.accept(this);
    }
  }

  @override
  void visitIDSelector(InterpolatedIDSelector node) {
    visitInterpolation(node.name);
  }

  @override
  void visitParentSelector(InterpolatedParentSelector node) {
    node.suffix.andThen(visitInterpolation);
  }

  @override
  void visitPlaceholderSelector(InterpolatedPlaceholderSelector node) {
    visitInterpolation(node.name);
  }

  @override
  void visitPseudoSelector(InterpolatedPseudoSelector node) {
    visitInterpolation(node.name);
    node.argument.andThen(visitInterpolation);
    node.selector.andThen(visitSelectorList);
  }

  @override
  void visitSelectorList(InterpolatedSelectorList node) {
    for (var component in node.components) {
      visitComplexSelector(component);
    }
  }

  @override
  void visitTypeSelector(InterpolatedTypeSelector node) {
    visitQualifiedName(node.name);
  }

  @override
  void visitUniversalSelector(InterpolatedUniversalSelector node) {
    node.namespace.andThen(visitInterpolation);
  }

  @override
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
