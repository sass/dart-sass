// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../utils.dart';
import '../selector.dart';

/// A component of a [ComplexSelector].
///
/// This a [CompoundSelector] with one or more trailing [Combinator]s.
///
/// {@category Selector}
@sealed
class ComplexSelectorComponent {
  /// This component's compound selector.
  final CompoundSelector selector;

  /// This selector's combinators.
  ///
  /// If this is empty, that indicates that it has an implicit descendent
  /// combinator. If it's more than one element, that means it's invalid CSS;
  /// however, we still support this for backwards-compatibility purposes.
  final List<Combinator> combinators;

  ComplexSelectorComponent(this.selector, Iterable<Combinator> combinators)
      : combinators = List.unmodifiable(combinators);

  /// Returns a copy of `this` with [combinators] added to the end of
  /// [this.combinators].
  ///
  /// @nodoc
  @internal
  ComplexSelectorComponent withAdditionalCombinators(
          List<Combinator> combinators) =>
      combinators.isEmpty
          ? this
          : ComplexSelectorComponent(
              selector, [...this.combinators, ...combinators]);

  int get hashCode => selector.hashCode ^ listHash(combinators);

  bool operator ==(Object other) =>
      other is ComplexSelectorComponent &&
      selector == other.selector &&
      listEquals(combinators, other.combinators);

  String toString() =>
      selector.toString() +
      combinators.map((combinator) => ' $combinator').join('');
}
