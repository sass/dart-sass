// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass.dart';

/// An interface for [visitors][] that traverse SassScript expressions.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
///
/// {@category Visitor}
abstract interface class ExpressionVisitor<T> {
  T visitBinaryOperationExpression(BinaryOperationExpression node);
  T visitBooleanExpression(BooleanExpression node);
  T visitColorExpression(ColorExpression node);
  T visitInterpolatedFunctionExpression(InterpolatedFunctionExpression node);
  T visitFunctionExpression(FunctionExpression node);
  T visitIfExpression(IfExpression node);
  T visitListExpression(ListExpression node);
  T visitMapExpression(MapExpression node);
  T visitNullExpression(NullExpression node);
  T visitNumberExpression(NumberExpression node);
  T visitParenthesizedExpression(ParenthesizedExpression node);
  T visitSelectorExpression(SelectorExpression node);
  T visitStringExpression(StringExpression node);
  T visitSupportsExpression(SupportsExpression node);
  T visitUnaryOperationExpression(UnaryOperationExpression node);
  T visitValueExpression(ValueExpression node);
  T visitVariableExpression(VariableExpression node);
}
