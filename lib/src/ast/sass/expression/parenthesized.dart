// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// An expression wrapped in parentheses.
///
/// {@category AST}
final class ParenthesizedExpression(
  /// The internal expression.
  final Expression expression,
  @override final FileSpan span,
) extends Expression {
  @override
  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitParenthesizedExpression(this);

  @override
  String toString() => "($expression)";
}
