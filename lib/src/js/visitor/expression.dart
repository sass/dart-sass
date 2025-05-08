// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import '../../ast/sass.dart';
import '../../visitor/interface/expression.dart';
import '../hybrid/binary_operation_expression.dart';
import '../hybrid/interpolated_function_expression.dart';
import '../hybrid/function_expression.dart';
import '../hybrid/if_expression.dart';
import '../hybrid/string_expression.dart';
import '../hybrid/supports_expression.dart';

/// A wrapper around a JS object that implements the [ExpressionVisitor] methods.
class JSExpressionVisitor implements ExpressionVisitor<JSAny?> {
  final JSExpressionVisitorObject _inner;

  JSExpressionVisitor(this._inner);

  JSAny? visitBinaryOperationExpression(BinaryOperationExpression node) =>
      _inner.visitBinaryOperationExpression(node.toJS);
  JSAny? visitBooleanExpression(BooleanExpression node) =>
      _inner.visitBooleanExpression(node as JSObject);
  JSAny? visitColorExpression(ColorExpression node) =>
      _inner.visitColorExpression(node as JSObject);
  JSAny? visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) =>
      _inner.visitInterpolatedFunctionExpression(node.toJS);
  JSAny? visitFunctionExpression(FunctionExpression node) =>
      _inner.visitFunctionExpression(node.toJS);
  JSAny? visitIfExpression(IfExpression node) =>
      _inner.visitIfExpression(node.toJS);
  JSAny? visitListExpression(ListExpression node) =>
      _inner.visitListExpression(node as JSObject);
  JSAny? visitMapExpression(MapExpression node) =>
      _inner.visitMapExpression(node as JSObject);
  JSAny? visitNullExpression(NullExpression node) =>
      _inner.visitNullExpression(node as JSObject);
  JSAny? visitNumberExpression(NumberExpression node) =>
      _inner.visitNumberExpression(node as JSObject);
  JSAny? visitParenthesizedExpression(ParenthesizedExpression node) =>
      _inner.visitParenthesizedExpression(node as JSObject);
  JSAny? visitSelectorExpression(SelectorExpression node) =>
      _inner.visitSelectorExpression(node as JSObject);
  JSAny? visitStringExpression(StringExpression node) =>
      _inner.visitStringExpression(node.toJS);
  JSAny? visitSupportsExpression(SupportsExpression node) =>
      _inner.visitSupportsExpression(node.toJS);
  JSAny? visitUnaryOperationExpression(UnaryOperationExpression node) =>
      _inner.visitUnaryOperationExpression(node as JSObject);
  JSAny? visitValueExpression(ValueExpression node) =>
      _inner.visitValueExpression(node as JSObject);
  JSAny? visitVariableExpression(VariableExpression node) =>
      _inner.visitVariableExpression(node as JSObject);
}

@anonymous
extension type JSExpressionVisitorObject._(JSObject _) implements JSObject {
  external JSAny? visitBinaryOperationExpression(
    JSBinaryOperationExpression node,
  );
  external JSAny? visitBooleanExpression(JSObject node);
  external JSAny? visitColorExpression(JSObject node);
  external JSAny? visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  );
  external JSAny? visitFunctionExpression(JSFunctionExpression node);
  external JSAny? visitIfExpression(JSIfExpression node);
  external JSAny? visitListExpression(JSObject node);
  external JSAny? visitMapExpression(JSObject node);
  external JSAny? visitNullExpression(JSObject node);
  external JSAny? visitNumberExpression(JSObject node);
  external JSAny? visitParenthesizedExpression(JSObject node);
  external JSAny? visitSelectorExpression(JSObject node);
  external JSAny? visitStringExpression(JSStringExpression node);
  external JSAny? visitSupportsExpression(JSSupportsExpression node);
  external JSAny? visitUnaryOperationExpression(JSObject node);
  external JSAny? visitValueExpression(JSObject node);
  external JSAny? visitVariableExpression(JSObject node);
}
