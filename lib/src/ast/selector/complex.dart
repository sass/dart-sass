// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../extend/functions.dart';
import '../../logger.dart';
import '../../parse/selector.dart';
import '../../utils.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A complex selector.
///
/// A complex selector is composed of [CompoundSelector]s separated by
/// [Combinator]s. It selects elements based on their parent selectors.
///
/// {@category AST}
/// {@category Parsing}
@sealed
class ComplexSelector extends Selector {
  /// This selector's leading combinators.
  ///
  /// If this is empty, that indicates that it has no leading combinator. If
  /// it's more than one element, that means it's invalid CSS; however, we still
  /// support this for backwards-compatibility purposes.
  final List<Combinator> leadingCombinators;

  /// The components of this selector.
  ///
  /// This is only empty if [leadingCombinators] is not empty.
  ///
  /// Descendant combinators aren't explicitly represented here. If two
  /// [CompoundSelector]s are adjacent to one another, there's an implicit
  /// descendant combinator between them.
  ///
  /// It's possible for multiple [Combinator]s to be adjacent to one another.
  /// This isn't valid CSS, but Sass supports it for CSS hack purposes.
  final List<ComplexSelectorComponent> components;

  /// Whether a line break should be emitted *before* this selector.
  ///
  /// @nodoc
  @internal
  final bool lineBreak;

  /// This selector's specificity.
  ///
  /// Specificity is represented in base 1000. The spec says this should be
  /// "sufficiently high"; it's extremely unlikely that any single selector
  /// sequence will contain 1000 simple selectors.
  late final int specificity = components.fold(
      0, (sum, component) => sum + component.selector.specificity);

  /// If this compound selector is composed of a single compound selector with
  /// no combinators, returns it.
  ///
  /// Otherwise, returns null.
  ///
  /// @nodoc
  @internal
  CompoundSelector? get singleCompound => leadingCombinators.isEmpty &&
          components.length == 1 &&
          components.first.combinators.isEmpty
      ? components.first.selector
      : null;

  ComplexSelector(Iterable<Combinator> leadingCombinators,
      Iterable<ComplexSelectorComponent> components,
      {this.lineBreak = false})
      : leadingCombinators = List.unmodifiable(leadingCombinators),
        components = List.unmodifiable(components) {
    if (this.leadingCombinators.isEmpty && this.components.isEmpty) {
      throw ArgumentError(
          "leadingCombinators and components may not both be empty.");
    }
  }

  /// Parses a complex selector from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  /// [allowParent] controls whether a [ParentSelector] is allowed in this
  /// selector.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory ComplexSelector.parse(String contents,
          {Object? url, Logger? logger, bool allowParent = true}) =>
      SelectorParser(contents,
              url: url, logger: logger, allowParent: allowParent)
          .parseComplexSelector();

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitComplexSelector(this);

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly matching more.
  bool isSuperselector(ComplexSelector other) =>
      leadingCombinators.isEmpty &&
      other.leadingCombinators.isEmpty &&
      complexIsSuperselector(components, other.components);

  /// Returns a copy of `this` with [combinators] added to the end of the final
  /// component in [components].
  ///
  /// If [forceLineBreak] is `true`, this will mark the new complex selector as
  /// having a line break.
  ///
  /// @nodoc
  @internal
  ComplexSelector withAdditionalCombinators(List<Combinator> combinators,
      {bool forceLineBreak = false}) {
    if (combinators.isEmpty) {
      return this;
    } else if (components.isEmpty) {
      return ComplexSelector([...leadingCombinators, ...combinators], const [],
          lineBreak: lineBreak || forceLineBreak);
    } else {
      return ComplexSelector(
          leadingCombinators,
          [
            ...components.exceptLast,
            components.last.withAdditionalCombinators(combinators)
          ],
          lineBreak: lineBreak || forceLineBreak);
    }
  }

  /// Returns a copy of `this` with an additional [component] added to the end.
  ///
  /// If [forceLineBreak] is `true`, this will mark the new complex selector as
  /// having a line break.
  ///
  /// @nodoc
  @internal
  ComplexSelector withAdditionalComponent(ComplexSelectorComponent component,
          {bool forceLineBreak = false}) =>
      ComplexSelector(leadingCombinators, [...components, component],
          lineBreak: lineBreak || forceLineBreak);

  /// Returns a copy of `this` with [child]'s combinators added to the end.
  ///
  /// If [child] has [leadingCombinators], they're appended to `this`'s last
  /// combinator. This does _not_ resolve parent selectors.
  ///
  /// If [forceLineBreak] is `true`, this will mark the new complex selector as
  /// having a line break.
  ///
  /// @nodoc
  @internal
  ComplexSelector concatenate(ComplexSelector child,
      {bool forceLineBreak = false}) {
    if (child.leadingCombinators.isEmpty) {
      return ComplexSelector(
          leadingCombinators, [...components, ...child.components],
          lineBreak: lineBreak || child.lineBreak || forceLineBreak);
    } else if (components.isEmpty) {
      return ComplexSelector(
          [...leadingCombinators, ...child.leadingCombinators],
          child.components,
          lineBreak: lineBreak || child.lineBreak || forceLineBreak);
    } else {
      return ComplexSelector(
          leadingCombinators,
          [
            ...components.exceptLast,
            components.last.withAdditionalCombinators(child.leadingCombinators),
            ...child.components
          ],
          lineBreak: lineBreak || child.lineBreak || forceLineBreak);
    }
  }

  int get hashCode => listHash(leadingCombinators) ^ listHash(components);

  bool operator ==(Object other) =>
      other is ComplexSelector &&
      listEquals(leadingCombinators, other.leadingCombinators) &&
      listEquals(components, other.components);
}
