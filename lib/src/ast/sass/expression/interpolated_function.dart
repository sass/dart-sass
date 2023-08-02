// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../interpolation.dart';

/// An interpolated function invocation.
///
/// This is always a plain CSS function.
///
/// {@category AST}
final class InterpolatedFunctionExpression
    implements Expression, CallableInvocation {
  /// The name of the function being invoked.
  final Interpolation name;

  /// The arguments to pass to the function.
  final ArgumentInvocation arguments;

  final FileSpan span;

  InterpolatedFunctionExpression(this.name, this.arguments, this.span);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitInterpolatedFunctionExpression(this);

  String toString() => '$name$arguments';
}
