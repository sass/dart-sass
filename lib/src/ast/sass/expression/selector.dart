// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A parent selector reference, `&`.
///
/// {@category AST}
final class SelectorExpression extends Expression {
  @override
  final FileSpan span;

  SelectorExpression(this.span);

  @override
  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitSelectorExpression(this);

  @override
  String toString() => "&";
}
