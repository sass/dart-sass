// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../interpolation.dart';
import '../supports_condition.dart';
import 'operation.dart';

/// A negated condition.
///
/// {@category AST}
@sealed
class SupportsNegation implements SupportsCondition {
  /// The condition that's been negated.
  final SupportsCondition condition;

  final FileSpan span;

  SupportsNegation(this.condition, this.span);

  Interpolation toInterpolation() {
    var needsParens =
        condition is SupportsNegation || condition is SupportsOperation;
    return Interpolation.concat([
      "not ",
      if (needsParens) "(",
      condition.toInterpolation(),
      if (needsParens) ")"
    ], span);
  }

  String toString() {
    if (condition is SupportsNegation || condition is SupportsOperation) {
      return "not ($condition)";
    } else {
      return "not $condition";
    }
  }
}
