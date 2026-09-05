// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../expression.dart';
import '../interpolation.dart';
import '../supports_condition.dart';

/// An interpolated condition.
///
/// {@category AST}
final class SupportsInterpolation implements SupportsCondition {
  /// The expression in the interpolation.
  final Expression expression;

  @override
  final FileSpan span;

  SupportsInterpolation(this.expression, this.span);

  /// @nodoc
  @override
  @internal
  Interpolation toInterpolation() => Interpolation([expression], [span], span);

  /// @nodoc
  @override
  @internal
  SupportsInterpolation withSpan(FileSpan span) =>
      SupportsInterpolation(expression, span);

  @override
  String toString() => "#{$expression}";
}
