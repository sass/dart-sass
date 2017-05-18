// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../ast/sass.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';

/// A ternary expression.
///
/// This is defined as a separate syntactic construct rather than a normal
/// function because only one of the `$if-true` and `$if-false` arguments are
/// evaluated.
class IfExpression implements Expression, CallableInvocation {
  /// The declaration of `if()`, as though it were a normal function.
  static final declaration =
      new ArgumentDeclaration.parse(r"$condition, $if-true, $if-false");

  /// The arguments passed to `if()`.
  final ArgumentInvocation arguments;

  final FileSpan span;

  IfExpression(this.arguments, this.span);

  T accept<T>(ExpressionVisitor<T> visitor) => visitor.visitIfExpression(this);

  String toString() => "if$arguments";
}
