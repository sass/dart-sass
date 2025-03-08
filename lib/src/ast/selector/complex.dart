// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../exception.dart';
import '../../extend/functions.dart';
import '../../parse/selector.dart';
import '../../util/nullable.dart';
import '../../utils.dart';
import '../../visitor/interface/selector.dart';
import '../css/value.dart';
import '../selector.dart';

/// A complex selector.
///
/// A complex selector is composed of [CompoundSelector]s separated by
/// [Combinator]s. It selects elements based on their parent selectors.
///
/// {@category AST}
/// {@category Parsing}
final class ComplexSelector extends Selector {
  /// This selector's leading combinator, if it has one.
  final CssValue<Combinator>? leadingCombinator;

  /// The components of this selector.
  ///
  /// This is only empty if [leadingCombinator] is not null.
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
    0,
    (sum, component) => sum + component.selector.specificity,
  );

  /// Whether `this` is a CSS selector that's valid on its own at the root of
  /// the CSS document.
  ///
  /// Selectors with leading or trailing combinators are *not* stand-alone.
  bool get isStandAlone =>
      leadingCombinator == null && components.last.combinator == null;

  /// Whether `this` is a valid [relative selector].
  ///
  /// This allows leading combinators but not trailing combinators. For any
  /// selector where this returns true, [isStandAlone] will also return true.
  ///
  /// [relative selector]: https://www.w3.org/TR/selectors-4/#relative-selector
  bool get isRelative => switch (components) {
        [] => false,
        [..., ComplexSelectorComponent(combinator: var _?)] => false,
        _ => true,
      };

  /// Throws a [SassException] if `this` isn't a CSS selector that's valid in
  /// various places in the document, depending on the arguments passed.
  ///
  /// If [allowLeadingCombinator] or [allowTrailingCombinator] is `true`, this
  /// allows selectors with leading or trailing selector combinators,
  /// respectively. Otherwise, they produce errors after parsing. If both are
  /// true, all selectors are allowed and this does nothing.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  void assertValid({
    String? name,
    bool allowLeadingCombinator = false,
    bool allowTrailingCombinator = false,
  }) {
    if ((!allowLeadingCombinator && leadingCombinator != null) ||
        (!allowTrailingCombinator && !isRelative)) {
      throw SassScriptException(
        'Selectors that aren\'t valid on their own aren\'t allowed '
        'in this function.',
        name,
      ).withSpan(span);
    }
  }

  /// If this compound selector is composed of a single compound selector with
  /// no combinators, returns it.
  ///
  /// Otherwise, returns null.
  ///
  /// @nodoc
  @internal
  CompoundSelector? get singleCompound {
    if (leadingCombinator != null) return null;
    return switch (components) {
      [ComplexSelectorComponent(:var selector, combinator: null)] => selector,
      _ => null,
    };
  }

  ComplexSelector(
    Iterable<ComplexSelectorComponent> components,
    super.span, {
    this.leadingCombinator,
    this.lineBreak = false,
  }) : components = List.unmodifiable(components) {
    if (leadingCombinator == null && this.components.isEmpty) {
      throw ArgumentError(
        "components may only empty if leadingCombinator is non-null.",
      );
    }
  }

  /// Parses a complex selector from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  /// [allowParent] controls whether a [ParentSelector] is allowed in this
  /// selector.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory ComplexSelector.parse(
    String contents, {
    Object? url,
    bool allowParent = true,
  }) =>
      SelectorParser(
        contents,
        url: url,
        allowParent: allowParent,
      ).parseComplexSelector();

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitComplexSelector(this);

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly matching more.
  bool isSuperselector(ComplexSelector other) =>
      leadingCombinator == null &&
      other.leadingCombinator == null &&
      complexIsSuperselector(components, other.components);

  /// Returns a copy of `this` with [combinator] added to the beginning.
  ///
  /// Returns `null` if this already has a leading combinator.
  ///
  /// @nodoc
  @internal
  ComplexSelector? prependCombinator(CssValue<Combinator>? combinator) {
    if (combinator == null) return this;
    if (leadingCombinator != null) return null;
    return ComplexSelector(
      components,
      span,
      leadingCombinator: combinator,
      lineBreak: lineBreak,
    );
  }

  /// Returns a copy of `this` with [combinator] added to the end of the final
  /// component in [components].
  ///
  /// If [forceLineBreak] is `true`, this will mark the new complex selector as
  /// having a line break.
  ///
  /// Returns `null` if this already has a trailing combinator.
  ///
  /// @nodoc
  @internal
  ComplexSelector? withAdditionalCombinator(
    CssValue<Combinator>? combinator, {
    bool forceLineBreak = false,
  }) =>
      combinator == null
          ? this
          : switch (components) {
              [...var initial, var last] =>
                last.withAdditionalCombinator(combinator).andThen(
                      (newLast) => ComplexSelector(
                        [...initial, newLast],
                        span,
                        leadingCombinator: leadingCombinator,
                        lineBreak: lineBreak || forceLineBreak,
                      ),
                    ),
              [] => null,
            };

  /// Returns a copy of `this` with an additional [component] added to the end.
  ///
  /// If [forceLineBreak] is `true`, this will mark the new complex selector as
  /// having a line break.
  ///
  /// The [span] is used for the new selector.
  ///
  /// @nodoc
  @internal
  ComplexSelector withAdditionalComponent(
    ComplexSelectorComponent? component,
    FileSpan span, {
    bool forceLineBreak = false,
  }) =>
      component == null
          ? this
          : ComplexSelector(
              [...components, component],
              span,
              leadingCombinator: leadingCombinator,
              lineBreak: lineBreak || forceLineBreak,
            );

  /// Returns a copy of `this` with [child] added to the end.
  ///
  /// If [child] has [leadingCombinator], they're appended to `this`'s last
  /// combinator. If that would produce an invalid selector, this returns `null`
  /// instead. This does _not_ resolve parent selectors.
  ///
  /// The [span] is used for the new selector.
  ///
  /// If [forceLineBreak] is `true`, this will mark the new complex selector as
  /// having a line break.
  ///
  /// @nodoc
  @internal
  ComplexSelector? concatenate(
    ComplexSelector child,
    FileSpan span, {
    bool forceLineBreak = false,
  }) =>
      switch (child.leadingCombinator) {
        null => ComplexSelector(
            [...components, ...child.components],
            span,
            leadingCombinator: leadingCombinator,
            lineBreak: lineBreak || child.lineBreak || forceLineBreak,
          ),
        var childCombinator => switch (components) {
            [...var initial, var last] =>
              last.withAdditionalCombinator(childCombinator).andThen(
                    (newLast) => ComplexSelector(
                      [...initial, newLast, ...child.components],
                      span,
                      leadingCombinator: leadingCombinator,
                      lineBreak: lineBreak || child.lineBreak || forceLineBreak,
                    ),
                  ),
            // If components is empty, this must have a leading combinator, which
            // isn't compatible with [childCombinator].
            _ => null,
          },
      };

  int get hashCode => leadingCombinator.hashCode ^ listHash(components);

  bool operator ==(Object other) =>
      other is ComplexSelector &&
      leadingCombinator == other.leadingCombinator &&
      listEquals(components, other.components);
}
