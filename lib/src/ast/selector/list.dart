// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../extend/functions.dart';
import '../../logger.dart';
import '../../parse/selector.dart';
import '../../utils.dart';
import '../../exception.dart';
import '../../value.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A selector list.
///
/// A selector list is composed of [ComplexSelector]s. It matches any element
/// that matches any of the component selectors.
///
/// {@category Selector}
@sealed
class SelectorList extends Selector {
  /// The components of this selector.
  ///
  /// This is never empty.
  final List<ComplexSelector> components;

  /// Whether this contains a [ParentSelector].
  bool get _containsParentSelector =>
      components.any(_complexContainsParentSelector);

  /// Returns a SassScript list that represents this selector.
  ///
  /// This has the same format as a list returned by `selector-parse()`.
  SassList get asSassList {
    return SassList(components.map((complex) {
      return SassList([
        for (var combinator in complex.leadingCombinators)
          SassString(combinator.toString(), quotes: false),
        for (var component in complex.components) ...[
          SassString(component.selector.toString(), quotes: false),
          for (var combinator in component.combinators)
            SassString(combinator.toString(), quotes: false)
        ]
      ], ListSeparator.space);
    }), ListSeparator.comma);
  }

  SelectorList(Iterable<ComplexSelector> components)
      : components = List.unmodifiable(components) {
    if (this.components.isEmpty) {
      throw ArgumentError("components may not be empty.");
    }
  }

  /// Parses a selector list from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  /// [allowParent] and [allowPlaceholder] control whether [ParentSelector]s or
  /// [PlaceholderSelector]s are allowed in this selector, respectively.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory SelectorList.parse(String contents,
          {Object? url,
          Logger? logger,
          bool allowParent = true,
          bool allowPlaceholder = true}) =>
      SelectorParser(contents,
              url: url,
              logger: logger,
              allowParent: allowParent,
              allowPlaceholder: allowPlaceholder)
          .parse();

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitSelectorList(this);

  /// Returns a [SelectorList] that matches only elements that are matched by
  /// both this and [other].
  ///
  /// If no such list can be produced, returns `null`.
  SelectorList? unify(SelectorList other) {
    var contents = [
      for (var complex1 in components)
        for (var complex2 in other.components)
          ...?unifyComplex([complex1, complex2])
    ];

    return contents.isEmpty ? null : SelectorList(contents);
  }

  /// Returns a new list with all [ParentSelector]s replaced with [parent].
  ///
  /// If [implicitParent] is true, this treats [ComplexSelector]s that don't
  /// contain an explicit [ParentSelector] as though they began with one.
  ///
  /// The given [parent] may be `null`, indicating that this has no parents. If
  /// so, this list is returned as-is if it doesn't contain any explicit
  /// [ParentSelector]s. If it does, this throws a [SassScriptException].
  SelectorList resolveParentSelectors(SelectorList? parent,
      {bool implicitParent = true}) {
    if (parent == null) {
      if (!_containsParentSelector) return this;
      throw SassScriptException(
          'Top-level selectors may not contain the parent selector "&".');
    }

    return SelectorList(flattenVertically(components.map((complex) {
      if (!_complexContainsParentSelector(complex)) {
        if (!implicitParent) return [complex];
        return parent.components
            .map((parentComplex) => parentComplex.concatenate(complex));
      }

      var newComplexes = <ComplexSelector>[];
      for (var component in complex.components) {
        var resolved = _resolveParentSelectorsCompound(component, parent);
        if (resolved == null) {
          if (newComplexes.isEmpty) {
            newComplexes.add(ComplexSelector(
                complex.leadingCombinators, [component],
                lineBreak: false));
          } else {
            for (var i = 0; i < newComplexes.length; i++) {
              newComplexes[i] =
                  newComplexes[i].withAdditionalComponent(component);
            }
          }
        } else if (newComplexes.isEmpty) {
          newComplexes.addAll(resolved);
        } else {
          var previousComplexes = newComplexes;
          newComplexes = [
            for (var newComplex in previousComplexes)
              for (var resolvedComplex in resolved)
                newComplex.concatenate(resolvedComplex)
          ];
        }
      }

      return newComplexes;
    })));
  }

  /// Returns whether [complex] contains a [ParentSelector].
  bool _complexContainsParentSelector(ComplexSelector complex) =>
      complex.components
          .any((component) => component.selector.components.any((simple) {
                if (simple is ParentSelector) return true;
                if (simple is! PseudoSelector) return false;
                var selector = simple.selector;
                return selector != null && selector._containsParentSelector;
              }));

  /// Returns a new selector list based on [component] with all
  /// [ParentSelector]s replaced with [parent].
  ///
  /// Returns `null` if [component] doesn't contain any [ParentSelector]s.
  Iterable<ComplexSelector>? _resolveParentSelectorsCompound(
      ComplexSelectorComponent component, SelectorList parent) {
    var simples = component.selector.components;
    var containsSelectorPseudo = simples.any((simple) {
      if (simple is! PseudoSelector) return false;
      var selector = simple.selector;
      return selector != null && selector._containsParentSelector;
    });
    if (!containsSelectorPseudo && simples.first is! ParentSelector) {
      return null;
    }

    var resolvedSimples = containsSelectorPseudo
        ? simples.map((simple) {
            if (simple is! PseudoSelector) return simple;
            var selector = simple.selector;
            if (selector == null) return simple;
            if (!selector._containsParentSelector) return simple;
            return simple.withSelector(
                selector.resolveParentSelectors(parent, implicitParent: false));
          })
        : simples;

    var parentSelector = simples.first;
    if (parentSelector is! ParentSelector) {
      return [
        ComplexSelector(const [], [
          ComplexSelectorComponent(
              CompoundSelector(resolvedSimples), component.combinators)
        ])
      ];
    } else if (simples.length == 1 && parentSelector.suffix == null) {
      return parent.withAdditionalCombinators(component.combinators).components;
    }

    return parent.components.map((complex) {
      var lastComponent = complex.components.last;
      if (lastComponent.combinators.isNotEmpty) {
        throw SassScriptException(
            'Parent "$complex" is incompatible with this selector.');
      }

      var suffix = parentSelector.suffix;
      var lastSimples = lastComponent.selector.components;
      var last = CompoundSelector(suffix == null
          ? [...lastSimples, ...resolvedSimples.skip(1)]
          : [
              ...lastSimples.exceptLast,
              lastSimples.last.addSuffix(suffix),
              ...resolvedSimples.skip(1)
            ]);

      return ComplexSelector(
          complex.leadingCombinators,
          [
            ...complex.components.exceptLast,
            ComplexSelectorComponent(last, component.combinators)
          ],
          lineBreak: complex.lineBreak);
    });
  }

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly additional elements.
  bool isSuperselector(SelectorList other) =>
      listIsSuperselector(components, other.components);

  /// Returns a copy of `this` with [combinators] added to the end of each
  /// complex selector in [components].
  @internal
  SelectorList withAdditionalCombinators(List<Combinator> combinators) =>
      combinators.isEmpty
          ? this
          : SelectorList(components.map(
              (complex) => complex.withAdditionalCombinators(combinators)));

  int get hashCode => listHash(components);

  bool operator ==(Object other) =>
      other is SelectorList && listEquals(components, other.components);
}
