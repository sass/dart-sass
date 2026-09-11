// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../sass/interpolation.dart';
import '../../selector.dart';
import 'simple.dart';

/// A universal selector.
///
/// Unlike [UniversalSelector], this is parsed during the initial stylesheet
/// parse when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedUniversalSelector(
  @override final FileSpan span, {

  /// The selector namespace.
  final Interpolation? namespace,
}) extends InterpolatedSimpleSelector {
  /// Calls the appropriate visit method on [visitor].
  @override
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitUniversalSelector(this);

  @override
  String toString() => switch (namespace) {
    var namespace? => '$namespace|*',
    _ => '*',
  };
}
