// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../css/value.dart';
import '../selector.dart';

/// A component of a [ComplexSelector].
///
/// This a [CompoundSelector] with one or more trailing [Combinator]s.
///
/// {@category AST}
final class ComplexSelectorComponent {
  /// This component's compound selector.
  final CompoundSelector selector;

  /// This selector's trailing combinator, if it has one.
  ///
  /// If this is null, that indicates that it has an implicit descendent
  /// combinator.
  final CssValue<Combinator>? combinator;

  final FileSpan span;

  ComplexSelectorComponent(this.selector, this.span, {this.combinator});

  /// Returns a copy of `this` with [combinator] added to the end.
  ///
  /// Returns `null` if this already has a combinator.
  ///
  /// @nodoc
  @internal
  ComplexSelectorComponent? withAdditionalCombinator(
    CssValue<Combinator>? combinator,
  ) =>
      switch ((this.combinator, combinator)) {
        (_, null) => this,
        (null, var combinator?) =>
          ComplexSelectorComponent(selector, span, combinator: combinator),
        _ => null,
      };

  int get hashCode => selector.hashCode ^ combinator.hashCode;

  bool operator ==(Object other) =>
      other is ComplexSelectorComponent &&
      selector == other.selector &&
      combinator == other.combinator;

  String toString() =>
      selector.toString() + (combinator == null ? '' : ' $combinator');
}
