// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../css/value.dart';
import '../../selector.dart';
import '../interpolated_selector.dart';
import 'complex_component.dart';

/// A complex selector before interoplation is resolved.
///
/// Unlike [ComplexSelector], this is parsed during the initial stylesheet parse
/// when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedComplexSelector extends InterpolatedSelector {
  /// This selector's leading combinator.
  ///
  /// If this is null, that indicates that it has no leading combinator. It's only null if
  final CssValue<Combinator>? leadingCombinator;

  /// The components of this selector.
  ///
  /// This is only empty if [leadingCombinators] is not null.
  final List<InterpolatedComplexSelectorComponent> components;

  final FileSpan span;

  InterpolatedComplexSelector(
      Iterable<InterpolatedComplexSelectorComponent> components, this.span,
      {this.leadingCombinator})
      : components = List.unmodifiable(components) {
    if (leadingCombinator == null && this.components.isEmpty) {
      throw ArgumentError(
        "components may not be empty if leadingCombinator is null.",
      );
    }
  }

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitComplexSelector(this);

  String toString() => components.join(' ');
}
