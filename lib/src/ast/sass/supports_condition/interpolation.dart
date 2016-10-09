// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../expression.dart';
import '../supports_condition.dart';

/// An interpolated condition.
class SupportsInterpolation implements SupportsCondition {
  /// The expression in the interpolation.
  final Expression expression;

  final FileSpan span;

  SupportsInterpolation(this.expression, this.span);

  String toString() => "#{$expression}";
}
