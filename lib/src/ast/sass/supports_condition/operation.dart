// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../interpolation_buffer.dart';
import '../../../util/span.dart';
import '../boolean_operator.dart';
import '../interpolation.dart';
import '../supports_condition.dart';
import 'negation.dart';

/// An operation defining the relationship between two conditions.
///
/// {@category AST}
final class SupportsOperation implements SupportsCondition {
  /// The left-hand operand.
  final SupportsCondition left;

  /// The right-hand operand.
  final SupportsCondition right;

  /// The operator.
  final BooleanOperator operator;

  final FileSpan span;

  SupportsOperation(this.left, this.right, this.operator, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation() => (InterpolationBuffer()
        ..write(span.before(left.span).text)
        ..addInterpolation(left.toInterpolation())
        ..write(left.span.between(right.span).text)
        ..addInterpolation(right.toInterpolation())
        ..write(span.after(right.span).text))
      .interpolation(span);

  /// @nodoc
  @internal
  SupportsOperation withSpan(FileSpan span) =>
      SupportsOperation(left, right, operator, span);

  String toString() =>
      "${_parenthesize(left)} $operator ${_parenthesize(right)}";

  String _parenthesize(SupportsCondition condition) =>
      condition is SupportsNegation ||
              (condition is SupportsOperation && condition.operator == operator)
          ? "($condition)"
          : condition.toString();
}
