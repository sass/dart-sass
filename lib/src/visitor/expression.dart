// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/expression.dart';
import '../ast/expression/identifier.dart';
import '../ast/expression/interpolation.dart';
import '../ast/expression/list.dart';
import '../ast/expression/string.dart';

class ExpressionVisitor<T> {
  T visit(Expression expression) => expression.visit(this);

  T visitIdentifierExpression(IdentifierExpression node) {
    visitInterpolationExpression(node.text);
    return null;
  }

  T visitInterpolationExpression(InterpolationExpression node) {
    for (var value in node.contents) {
      if (value is Expression) value.visit(this);
    }
    return null;
  }

  T visitListExpression(ListExpression node) {
    for (var expression in node.contents) {
      expression.visit(this);
    }
    return null;
  }

  T visitStringExpression(StringExpression node) {
    visitInterpolationExpression(node.text);
    return null;
  }
}
