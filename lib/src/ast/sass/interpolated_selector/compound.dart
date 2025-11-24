// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../selector.dart';
import '../interpolated_selector.dart';
import 'simple.dart';

/// A compound selector before interoplation is resolved.
///
/// Unlike [CompoundSelector], this is parsed during the initial stylesheet parse
/// when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedCompoundSelector extends InterpolatedSelector {
  /// The components of this selector.
  final List<InterpolatedSimpleSelector> components;

  FileSpan get span => components.length == 1
      ? components.first.span
      : components.first.span.expand(components.last.span);

  InterpolatedCompoundSelector(Iterable<InterpolatedSimpleSelector> components)
      : components = List.unmodifiable(components) {
    if (this.components.isEmpty) {
      throw ArgumentError("components may not be empty.");
    }
  }

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitCompoundSelector(this);

  String toString() => components.join('');
}
