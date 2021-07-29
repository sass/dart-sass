// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A parent selector reference, `&`.
///
/// {@category AST}
@sealed
class SelectorExpression implements Expression {
  final FileSpan span;

  SelectorExpression(this.span);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitSelectorExpression(this);

  String toString() => "&";
}
