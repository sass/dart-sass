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
///
/// The default implementation of the visit methods all return `null`.
abstract class RecursiveAstVisitor<T> extends RecursiveStatementVisitor<T>
    implements ExpressionVisitor<T> {
  void visitExpression(Expression expression) {
    expression.accept(this);
  }

  T visitBinaryOperationExpression(BinaryOperationExpression node) {
    node.left.accept(this);
    node.right.accept(this);
    return null;
  }

  T visitBooleanExpression(BooleanExpression node) => null;

  T visitColorExpression(ColorExpression node) => null;

  T visitForwardRule(ForwardRule node) {
    for (var variable in node.configuration) {
      variable.expression.accept(this);
    }
    return null;
  }

  T visitFunctionExpression(FunctionExpression node) {
    visitInterpolation(node.name);
    visitArgumentInvocation(node.arguments);
    return null;
  }

  T visitIfExpression(IfExpression node) {
    visitArgumentInvocation(node.arguments);
    return null;
  }

  T visitListExpression(ListExpression node) {
    for (var item in node.contents) {
      item.accept(this);
    }
    return null;
  }

  T visitMapExpression(MapExpression node) {
    for (var pair in node.pairs) {
      pair.item1.accept(this);
      pair.item2.accept(this);
    }
    return null;
  }

  T visitNullExpression(NullExpression node) => null;

  T visitNumberExpression(NumberExpression node) => null;

  T visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  T visitSelectorExpression(SelectorExpression node) => null;

  T visitStringExpression(StringExpression node) {
    visitInterpolation(node.text);
    return null;
  }

  T visitUnaryOperationExpression(UnaryOperationExpression node) =>
      node.operand.accept(this);

  T visitUseRule(UseRule node) {
    for (var variable in node.configuration) {
      variable.expression.accept(this);
    }
    return null;
  }

  T visitValueExpression(ValueExpression node) => null;

  T visitVariableExpression(VariableExpression node) => null;
}
