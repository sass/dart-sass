// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import 'simple.dart';

/// A percentage selecting a step in a `@keyframes` rule.
///
/// {@category AST}
final class InterpolatedKeyframePercentage extends InterpolatedSimpleSelector {
  @override
  final FileSpan span;

  /// The percentage as written in the source, including the percent sign.
  final String percentage;

  new(this.span) : percentage = span.text;

  @override
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitKeyframePercentage(this);

  @override
  String toString() => percentage;
}
