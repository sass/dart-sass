// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

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
      _inner.visitBooleanExpression(node.toUnsafeWrapper);
  JSAny? visitColorExpression(ColorExpression node) =>
      _inner.visitColorExpression(node.toUnsafeWrapper);
  JSAny? visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) =>
      _inner.visitInterpolatedFunctionExpression(node.toJS);
  JSAny? visitFunctionExpression(FunctionExpression node) =>
      _inner.visitFunctionExpression(node.toJS);
  JSAny? visitIfExpression(IfExpression node) =>
      _inner.visitIfExpression(node.toJS);
  JSAny? visitListExpression(ListExpression node) =>
      _inner.visitListExpression(node.toUnsafeWrapper);
  JSAny? visitMapExpression(MapExpression node) =>
      _inner.visitMapExpression(node.toUnsafeWrapper);
  JSAny? visitNullExpression(NullExpression node) =>
      _inner.visitNullExpression(node.toUnsafeWrapper);
  JSAny? visitNumberExpression(NumberExpression node) =>
      _inner.visitNumberExpression(node.toUnsafeWrapper);
  JSAny? visitParenthesizedExpression(ParenthesizedExpression node) =>
      _inner.visitParenthesizedExpression(node.toUnsafeWrapper);
  JSAny? visitSelectorExpression(SelectorExpression node) =>
      _inner.visitSelectorExpression(node.toUnsafeWrapper);
  JSAny? visitStringExpression(StringExpression node) =>
      _inner.visitStringExpression(node.toJS);
  JSAny? visitSupportsExpression(SupportsExpression node) =>
      _inner.visitSupportsExpression(node.toJS);
  JSAny? visitUnaryOperationExpression(UnaryOperationExpression node) =>
      _inner.visitUnaryOperationExpression(node.toUnsafeWrapper);
  JSAny? visitValueExpression(ValueExpression node) =>
      _inner.visitValueExpression(node.toUnsafeWrapper);
  JSAny? visitVariableExpression(VariableExpression node) =>
      _inner.visitVariableExpression(node.toUnsafeWrapper);
}

extension type JSExpressionVisitorObject._(JSObject _) implements JSObject {
  external JSAny? visitBinaryOperationExpression(
    UnsafeDartWrapper<BinaryOperationExpression> node,
  );
  external JSAny? visitBooleanExpression(
      UnsafeDartWrapper<BooleanExpression> node);
  external JSAny? visitColorExpression(UnsafeDartWrapper<ColorExpression> node);
  external JSAny? visitInterpolatedFunctionExpression(
    UnsafeDartWrapper<InterpolatedFunctionExpression> node,
  );
  external JSAny? visitFunctionExpression(
      UnsafeDartWrapper<FunctionExpression> node);
  external JSAny? visitIfExpression(UnsafeDartWrapper<IfExpression> node);
  external JSAny? visitListExpression(UnsafeDartWrapper<ListExpression> node);
  external JSAny? visitMapExpression(UnsafeDartWrapper<MapExpression> node);
  external JSAny? visitNullExpression(UnsafeDartWrapper<NullExpression> node);
  external JSAny? visitNumberExpression(
      UnsafeDartWrapper<NumberExpression> node);
  external JSAny? visitParenthesizedExpression(
      UnsafeDartWrapper<ParenthesizedExpression> node);
  external JSAny? visitSelectorExpression(
      UnsafeDartWrapper<SelectorExpression> node);
  external JSAny? visitStringExpression(
      UnsafeDartWrapper<StringExpression> node);
  external JSAny? visitSupportsExpression(
      UnsafeDartWrapper<SupportsExpression> node);
  external JSAny? visitUnaryOperationExpression(
      UnsafeDartWrapper<UnaryOperationExpression> node);
  external JSAny? visitValueExpression(UnsafeDartWrapper<ValueExpression> node);
  external JSAny? visitVariableExpression(
      UnsafeDartWrapper<VariableExpression> node);
}
