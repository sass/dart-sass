// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../../../value/number.dart';
import '../expression.dart';

/// A number literal.
///
/// {@category AST}
@sealed
class NumberExpression implements Expression {
  /// The numeric value.
  final double value;

  /// The number's unit, or `null`.
  final String? unit;

  final FileSpan span;

  NumberExpression(num value, this.span, {this.unit})
      : value = value.toDouble();

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitNumberExpression(this);

  String toString() => SassNumber(value, unit).toString();
}
