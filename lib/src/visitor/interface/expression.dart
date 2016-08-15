// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass/expression.dart';

abstract class ExpressionVisitor<T> {
  T visitVariableExpression(VariableExpression node) => null;
  T visitBooleanExpression(BooleanExpression node) => null;
  T visitNumberExpression(NumberExpression node) => null;
  T visitColorExpression(ColorExpression node) => null;

  T visitUnaryOperatorExpression(UnaryOperatorExpression node) {
    node.operand.accept(this);
    return null;
  }

  T visitIdentifierExpression(IdentifierExpression node) {
    visitInterpolationExpression(node.text);
    return null;
  }

  T visitListExpression(ListExpression node) {
    for (var expression in node.contents) {
      expression.accept(this);
    }
    return null;
  }

  T visitMapExpression(MapExpression node) {
    for (var pair in node.pairs) {
      pair.first.accept(this);
      pair.last.accept(this);
    }
    return null;
  }

  T visitStringExpression(StringExpression node) {
    visitInterpolationExpression(node.text);
    return null;
  }

  T visitInterpolationExpression(InterpolationExpression node) {
    for (var value in node.contents) {
      if (value is Expression) value.accept(this);
    }
    return null;
  }
}
