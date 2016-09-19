// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass.dart';

abstract class ExpressionVisitor<T> {
  T visitBinaryOperationExpression(BinaryOperationExpression node);
  T visitBooleanExpression(BooleanExpression node);
  T visitColorExpression(ColorExpression node);
  T visitFunctionExpression(FunctionExpression node);
  T visitIdentifierExpression(IdentifierExpression node);
  T visitListExpression(ListExpression node);
  T visitMapExpression(MapExpression node);
  T visitNullExpression(NullExpression node);
  T visitNumberExpression(NumberExpression node);
  T visitSelectorExpression(SelectorExpression node);
  T visitStringExpression(StringExpression node);
  T visitUnaryOperationExpression(UnaryOperationExpression node);
  T visitVariableExpression(VariableExpression node);
}
