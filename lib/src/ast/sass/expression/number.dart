// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A number literal.
class NumberExpression implements Expression {
  /// The numeric value.
  final num value;

  /// The number's unit, or `null`.
  final String unit;

  final FileSpan span;

  NumberExpression(this.value, this.span, {this.unit});

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitNumberExpression(this);

  String toString() => "${value}${unit ?? ''}";
}
