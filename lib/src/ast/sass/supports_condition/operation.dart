// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../supports_condition.dart';
import 'negation.dart';

/// An operation defining the relationship between two conditions.
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
      throw new ArgumentError.value(
          operator, 'operator', 'may only be "and" or "or".');
    }
  }

  String toString() =>
      "${_parenthesize(left)} ${operator} ${_parenthesize(right)}";

  String _parenthesize(SupportsCondition condition) =>
      condition is SupportsNegation ||
              (condition is SupportsOperation && condition.operator == operator)
          ? "($condition)"
          : condition.toString();
}
