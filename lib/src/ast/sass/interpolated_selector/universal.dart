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
final class InterpolatedUniversalSelector extends InterpolatedSimpleSelector {
  /// The selector namespace.
  final Interpolation? namespace;

  final FileSpan span;

  InterpolatedUniversalSelector(this.span, {this.namespace});

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitUniversalSelector(this);

  String toString() =>
      switch (namespace) { var namespace? => '$namespace|*', _ => '*' };
}
