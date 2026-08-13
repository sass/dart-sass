// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../../../value/number.dart';
import '../expression.dart';

/// A number literal.
///
/// {@category AST}
final class NumberExpression(
  /// The numeric value.
  final double value,
  @override final FileSpan span, {

  /// The number's unit, or `null`.
  final String? unit,
}) extends Expression {
  @override
  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitNumberExpression(this);

  @override
  String toString() => SassNumber(value, unit).toString();
}
