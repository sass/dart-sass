// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../supports_condition.dart';

/// An expression-level `@supports` condition.
///
/// This appears only in the modifiers that come after a plain-CSS `@import`. It
/// doesn't include the function name wrapping the condition.
///
/// {@category AST}
@sealed
class SupportsExpression implements Expression {
  /// The condition itself.
  final SupportsCondition condition;

  FileSpan get span => condition.span;

  SupportsExpression(this.condition);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitSupportsExpression(this);

  String toString() => condition.toString();
}
