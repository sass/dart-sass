// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../ast/sass.dart';
import '../../visitor/interface/if_condition_expression.dart';

/// A wrapper around a JS object that implements the
/// [IfConditionExpressionVisitor] methods.
class JSIfConditionExpressionVisitor
    implements IfConditionExpressionVisitor<Object?> {
  final JSIfConditionExpressionVisitorObject _inner;

  JSIfConditionExpressionVisitor(this._inner);

  Object? visitIfConditionParenthesized(IfConditionParenthesized node) =>
      _inner.visitIfConditionParenthesized(node);
  Object? visitIfConditionNegation(IfConditionNegation node) =>
      _inner.visitIfConditionNegation(node);
  Object? visitIfConditionOperation(IfConditionOperation node) =>
      _inner.visitIfConditionOperation(node);
  Object? visitIfConditionFunction(IfConditionFunction node) =>
      _inner.visitIfConditionFunction(node);
  Object? visitIfConditionSass(IfConditionSass node) =>
      _inner.visitIfConditionSass(node);
  Object? visitIfConditionRaw(IfConditionRaw node) =>
      _inner.visitIfConditionRaw(node);
}

@JS()
class JSIfConditionExpressionVisitorObject {
  external Object? visitIfConditionParenthesized(IfConditionParenthesized node);
  external Object? visitIfConditionNegation(IfConditionNegation node);
  external Object? visitIfConditionOperation(IfConditionOperation node);
  external Object? visitIfConditionFunction(IfConditionFunction node);
  external Object? visitIfConditionSass(IfConditionSass node);
  external Object? visitIfConditionRaw(IfConditionRaw node);
}
