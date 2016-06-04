// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../../ast/sass/expression.dart';
import '../../../environment.dart';
import '../../../value.dart';
import '../expression.dart';

class PerformExpressionVisitor extends ExpressionVisitor<Value> {
  final Environment _environment;

  PerformExpressionVisitor(this._environment);

  Value visit(Expression expression) => expression.accept(this);

  Value visitVariableExpression(VariableExpression node) {
    var result = _environment.getVariable(node.name);
    if (result != null) return result;

    // TODO: real exception
    throw node.span.message("undefined variable");
  }

  Value visitUnaryOperatorExpression(UnaryOperatorExpression node) {
    var operand = node.operand.accept(this);
    switch (node.operator) {
      case UnaryOperator.plus: return operand.unaryPlus();
      case UnaryOperator.minus: return operand.unaryMinus();
      case UnaryOperator.divide: return operand.unaryDivide();
      case UnaryOperator.not: return operand.unaryNot();
      default: throw new StateError("Unknown unary operator ${node.operator}.");
    }
  }

  SassIdentifier visitIdentifierExpression(IdentifierExpression node) =>
      new SassIdentifier(visitInterpolationExpression(node.text).text);

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      new SassBoolean(node.value);

  SassNumber visitNumberExpression(NumberExpression node) =>
      new SassNumber(node.value);

  SassColor visitColorExpression(ColorExpression node) => node.value;

  SassString visitInterpolationExpression(InterpolationExpression node) {
    return new SassString(node.contents.map((value) {
      if (value is String) return value;
      return (value as Expression).accept(this);
    }).join());
  }

  SassList visitListExpression(ListExpression node) => new SassList(
      node.contents.map((expression) => expression.accept(this)),
      node.separator);

  SassString visitStringExpression(StringExpression node) =>
      visitInterpolationExpression(node.text);
}
