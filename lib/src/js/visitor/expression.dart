// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../ast/sass.dart';
import '../../visitor/interface/expression.dart';

/// A wrapper around a JS object that implements the [ExpressionVisitor] methods.
class JSExpressionVisitor implements ExpressionVisitor<Object?> {
  final JSExpressionVisitorObject _inner;

  JSExpressionVisitor(this._inner);

  Object? visitBinaryOperationExpression(BinaryOperationExpression node) =>
      _inner.visitBinaryOperationExpression(node);
  Object? visitBooleanExpression(BooleanExpression node) =>
      _inner.visitBooleanExpression(node);
  Object? visitColorExpression(ColorExpression node) =>
      _inner.visitColorExpression(node);
  Object? visitInterpolatedFunctionExpression(
          InterpolatedFunctionExpression node) =>
      _inner.visitInterpolatedFunctionExpression(node);
  Object? visitFunctionExpression(FunctionExpression node) =>
      _inner.visitFunctionExpression(node);
  Object? visitIfExpression(IfExpression node) =>
      _inner.visitIfExpression(node);
  Object? visitListExpression(ListExpression node) =>
      _inner.visitListExpression(node);
  Object? visitMapExpression(MapExpression node) =>
      _inner.visitMapExpression(node);
  Object? visitNullExpression(NullExpression node) =>
      _inner.visitNullExpression(node);
  Object? visitNumberExpression(NumberExpression node) =>
      _inner.visitNumberExpression(node);
  Object? visitParenthesizedExpression(ParenthesizedExpression node) =>
      _inner.visitParenthesizedExpression(node);
  Object? visitSelectorExpression(SelectorExpression node) =>
      _inner.visitSelectorExpression(node);
  Object? visitStringExpression(StringExpression node) =>
      _inner.visitStringExpression(node);
  Object? visitSupportsExpression(SupportsExpression node) =>
      _inner.visitSupportsExpression(node);
  Object? visitUnaryOperationExpression(UnaryOperationExpression node) =>
      _inner.visitUnaryOperationExpression(node);
  Object? visitValueExpression(ValueExpression node) =>
      _inner.visitValueExpression(node);
  Object? visitVariableExpression(VariableExpression node) =>
      _inner.visitVariableExpression(node);
}

@JS()
class JSExpressionVisitorObject {
  external Object? visitBinaryOperationExpression(
      BinaryOperationExpression node);
  external Object? visitBooleanExpression(BooleanExpression node);
  external Object? visitColorExpression(ColorExpression node);
  external Object? visitInterpolatedFunctionExpression(
      InterpolatedFunctionExpression node);
  external Object? visitFunctionExpression(FunctionExpression node);
  external Object? visitIfExpression(IfExpression node);
  external Object? visitListExpression(ListExpression node);
  external Object? visitMapExpression(MapExpression node);
  external Object? visitNullExpression(NullExpression node);
  external Object? visitNumberExpression(NumberExpression node);
  external Object? visitParenthesizedExpression(ParenthesizedExpression node);
  external Object? visitSelectorExpression(SelectorExpression node);
  external Object? visitStringExpression(StringExpression node);
  external Object? visitSupportsExpression(SupportsExpression node);
  external Object? visitUnaryOperationExpression(UnaryOperationExpression node);
  external Object? visitValueExpression(ValueExpression node);
  external Object? visitVariableExpression(VariableExpression node);
}
