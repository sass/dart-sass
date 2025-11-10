// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../sass/interpolation.dart';
import '../../selector.dart';
import 'simple.dart';

/// A placeholder selector.
///
/// Unlike [PlaceholderSelector], this is parsed during the initial stylesheet
/// parse when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedPlaceholderSelector extends InterpolatedSimpleSelector {
  /// The name of the placeholder.
  final Interpolation name;

  FileSpan get span =>
      name.span.file.span(name.span.start.offset - 1, name.span.end.offset);

  InterpolatedPlaceholderSelector(this.name);

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitPlaceholderSelector(this);

  String toString() => '%$name';
}
