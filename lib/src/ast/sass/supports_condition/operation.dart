// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../interpolation.dart';
import '../supports_condition.dart';
import 'negation.dart';

/// An operation defining the relationship between two conditions.
///
/// {@category AST}
@sealed
class SupportsOperation implements SupportsCondition {
  /// The left-hand operand.
  final SupportsCondition left;

  /// The right-hand operand.
  final SupportsCondition right;

  /// The operator.
  ///
  /// Currently, this can be only `"and"` or `"or"`.
  final String operator;

  final FileSpan span;

  SupportsOperation(this.left, this.right, this.operator, this.span) {
    var lowerOperator = operator.toLowerCase();
    if (lowerOperator != "and" && lowerOperator != "or") {
      throw ArgumentError.value(
          operator, 'operator', 'may only be "and" or "or".');
    }
  }

  Interpolation toInterpolation() => Interpolation.concat([
        ..._parenthesizeInterpolation(left),
        " $operator ",
        ..._parenthesizeInterpolation(right)
      ], span);

  /// Returns a list that can be passed to [Interpolation.concat], with
  /// parentheses around [condition] if necessary.
  List<Object /* String | Expression | Interpolation */ >
      _parenthesizeInterpolation(SupportsCondition condition) => condition
                  is SupportsNegation ||
              (condition is SupportsOperation && condition.operator == operator)
          ? ["(", condition.toInterpolation(), ")"]
          : [condition.toInterpolation()];

  String toString() =>
      "${_parenthesizeString(left)} $operator ${_parenthesizeString(right)}";

  String _parenthesizeString(SupportsCondition condition) =>
      condition is SupportsNegation ||
              (condition is SupportsOperation && condition.operator == operator)
          ? "($condition)"
          : condition.toString();
}
