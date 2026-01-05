// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../css/value.dart';
import '../../selector.dart';
import '../node.dart';
import 'compound.dart';

/// A component of a [InterpolatedComplexSelector].
///
/// Unlike [ComplexSelectorComponent], this is parsed during the initial
/// stylesheet parse when `parseSelectors: true` is passed to
/// [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedComplexSelectorComponent implements SassNode {
  /// This component's compound selector.
  final InterpolatedCompoundSelector selector;

  /// This selector's combinator.
  ///
  /// If this is null, that indicates that it has an implicit descendent
  /// combinator.
  final CssValue<Combinator>? combinator;

  final FileSpan span;

  InterpolatedComplexSelectorComponent(this.selector, this.span,
      {this.combinator});

  String toString() => switch (combinator) {
        var combinator? => '$selector $combinator',
        _ => selector.toString()
      };
}
