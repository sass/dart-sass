// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import 'interface/expression.dart';
import 'recursive_statement.dart';

/// A visitor that recursively traverses each statement and expression in a Sass
/// AST.
///
/// This extends [RecursiveStatementVisitor] to traverse each expression in
/// addition to each statement.
abstract class RecursiveAstVisitor extends RecursiveStatementVisitor
    implements ExpressionVisitor<void> {
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

  void visitParenthesizedExpression(ParenthesizedExpression node) {}

  void visitSelectorExpression(SelectorExpression node) {}

  void visitStringExpression(StringExpression node) {
    visitInterpolation(node.text);
  }

  void visitUnaryOperationExpression(UnaryOperationExpression node) {
    node.operand.accept(this);
  }

  void visitUseRule(UseRule node) {
    for (var variable in node.configuration) {
      variable.expression.accept(this);
    }
  }

  void visitValueExpression(ValueExpression node) {}

  void visitVariableExpression(VariableExpression node) {}
}
