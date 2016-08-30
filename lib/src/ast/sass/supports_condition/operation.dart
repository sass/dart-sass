// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../supports_condition.dart';
import 'negation.dart';

class SupportsOperation implements SupportsCondition {
  final SupportsCondition left;

  final SupportsCondition right;

  final String operator;

  final FileSpan span;

  SupportsOperation(this.left, this.right, this.operator, this.span);

  String toString() =>
      "${_parenthesize(left)} ${operator} ${_parenthesize(right)}";

  String _parenthesize(SupportsCondition condition) =>
      condition is SupportsNegation ||
              (condition is SupportsOperation && condition.operator == operator)
          ? "($condition)"
          : condition.toString();
}
