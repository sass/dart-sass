// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A boolean literal, `true` or `false`.
class BooleanExpression implements Expression {
  /// The value of this expression.
  final bool value;

  final FileSpan span;

  BooleanExpression(this.value, this.span);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitBooleanExpression(this);

  String toString() => value.toString();
}
