// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass.dart';

/// An interface for [visitors] that traverse [IfConditionExpression]s.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
///
/// {@category Visitor}
abstract interface class IfConditionExpressionVisitor<T> {
  T visitIfConditionParenthesized(IfConditionParenthesized node);
  T visitIfConditionNegation(IfConditionNegation node);
  T visitIfConditionOperation(IfConditionOperation node);
  T visitIfConditionFunction(IfConditionFunction node);
  T visitIfConditionSass(IfConditionSass node);
  T visitIfConditionRaw(IfConditionRaw node);
}
