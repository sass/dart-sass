// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../sass/interpolation.dart';
import '../../selector.dart';
import 'simple.dart';

/// A parent selector.
///
/// Unlike [ParentSelector], this is parsed during the initial stylesheet parse
/// when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedParentSelector extends InterpolatedSimpleSelector {
  /// The suffix that will be added to the parent selector after it's been
  /// resolved.
  final Interpolation? suffix;

  final FileSpan span;

  InterpolatedParentSelector(this.span, {this.suffix});

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitParentSelector(this);

  String toString() => switch (suffix) { var suffix? => '&$suffix', _ => '&' };
}
