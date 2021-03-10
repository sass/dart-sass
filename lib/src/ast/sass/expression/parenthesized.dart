// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// An expression wrapped in parentheses.
class ParenthesizedExpression implements Expression {
  /// The internal expression.
  final Expression/*!*/ expression;

  final FileSpan span;

  ParenthesizedExpression(this.expression, this.span);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitParenthesizedExpression(this);

  String toString() => expression.toString();
}
