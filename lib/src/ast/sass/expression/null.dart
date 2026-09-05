// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A null literal.
///
/// {@category AST}
final class NullExpression(@override final FileSpan span) extends Expression {
  @override
  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitNullExpression(this);

  @override
  String toString() => "null";
}
