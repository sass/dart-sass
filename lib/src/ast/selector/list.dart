// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

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
/// A selector list is composed of [ComplexSelector]s. It matches an element
/// that matches any of the component selectors.
class SelectorList extends Selector {
  /// The components of this selector.
  ///
  /// This is never empty.
  final List<ComplexSelector> components;

  /// Whether this contains a [ParentSelector].
  bool get _containsParentSelector =>
      components.any(_complexContainsParentSelector);

  bool get isInvisible => components.every((complex) => complex.isInvisible);

  /// Returns a SassScript list that represents this selector.
  ///
  /// This has the same format as a list returned by `selector-parse()`.
  SassList get asSassList {
    return new SassList(components.map((complex) {
      return new SassList(
          complex.components.map((component) =>
              new SassString(component.toString(), quotes: false)),
          ListSeparator.space);
    }), ListSeparator.comma);
  }

  SelectorList(Iterable<ComplexSelector> components)
      : components = new List.unmodifiable(components) {
    if (this.components.isEmpty) {
      throw new ArgumentError("components may not be empty.");
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
          {url,
          Logger logger,
          bool allowParent: true,
          bool allowPlaceholder: true}) =>
      new SelectorParser(contents,
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
  SelectorList unify(SelectorList other) {
    var contents = components.expand((complex1) {
      return other.components.expand((complex2) {
        var unified = unifyComplex([complex1.components, complex2.components]);
        if (unified == null) return const <ComplexSelector>[];
        return unified.map((complex) => new ComplexSelector(complex));
      });
    }).toList();

    return contents.isEmpty ? null : new SelectorList(contents);
  }

  /// Returns a new list with all [ParentSelector]s replaced with [parent].
  ///
  /// If [implicitParent] is true, this treats [ComplexSelector]s that don't
  /// contain an explicit [ParentSelector] as though they began with one.
  ///
  /// The given [parent] may be `null`, indicating that this has no parents. If
  /// so, this list is returned as-is if it doesn't contain any explicit
  /// [ParentSelector]s. If it does, this throws a [SassScriptException].
  SelectorList resolveParentSelectors(SelectorList parent,
      {bool implicitParent: true}) {
    if (parent == null) {
      if (!_containsParentSelector) return this;
      throw new SassScriptException(
          'Top-level selectors may not contain the parent selector "&".');
    }

    return new SelectorList(flattenVertically(components.map((complex) {
      if (!_complexContainsParentSelector(complex)) {
        if (!implicitParent) return [complex];
        return parent.components.map((parentComplex) => new ComplexSelector(
            parentComplex.components.toList()..addAll(complex.components),
            lineBreak: complex.lineBreak || parentComplex.lineBreak));
      }

      var newComplexes = [<ComplexSelectorComponent>[]];
      var lineBreaks = <bool>[false];
      for (var component in complex.components) {
        if (component is CompoundSelector) {
          var resolved = _resolveParentSelectorsCompound(component, parent);
          if (resolved == null) {
            for (var newComplex in newComplexes) {
              newComplex.add(component);
            }
            continue;
          }

          var previousComplexes = newComplexes;
          var previousLineBreaks = lineBreaks;
          newComplexes = <List<ComplexSelectorComponent>>[];
          lineBreaks = <bool>[];
          var i = 0;
          for (var newComplex in previousComplexes) {
            var lineBreak = previousLineBreaks[i++];
            for (var resolvedComplex in resolved) {
              newComplexes
                  .add(newComplex.toList()..addAll(resolvedComplex.components));
              lineBreaks.add(lineBreak || resolvedComplex.lineBreak);
            }
          }
        } else {
          for (var newComplex in newComplexes) {
            newComplex.add(component);
          }
        }
      }

      var i = 0;
      return newComplexes.map((newComplex) =>
          new ComplexSelector(newComplex, lineBreak: lineBreaks[i++]));
    })));
  }

  /// Returns whether [complex] contains a [ParentSelector].
  bool _complexContainsParentSelector(ComplexSelector complex) =>
      complex.components.any((component) =>
          component is CompoundSelector &&
          component.components.any((simple) =>
              simple is ParentSelector ||
              (simple is PseudoSelector &&
                  simple.selector != null &&
                  simple.selector._containsParentSelector)));

  /// Returns a new [CompoundSelector] based on [compound] with all
  /// [ParentSelector]s replaced with [parent].
  ///
  /// Returns `null` if [compound] doesn't contain any [ParentSelector]s.
  Iterable<ComplexSelector> _resolveParentSelectorsCompound(
      CompoundSelector compound, SelectorList parent) {
    var containsSelectorPseudo = compound.components.any((simple) =>
        simple is PseudoSelector &&
        simple.selector != null &&
        simple.selector._containsParentSelector);
    if (!containsSelectorPseudo &&
        compound.components.first is! ParentSelector) {
      return null;
    }

    Iterable<SimpleSelector> resolvedMembers = containsSelectorPseudo
        ? compound.components.map((simple) {
            if (simple is PseudoSelector) {
              if (simple.selector == null) return simple;
              if (!simple.selector._containsParentSelector) return simple;
              return simple.withSelector(simple.selector
                  .resolveParentSelectors(parent, implicitParent: false));
            } else {
              return simple;
            }
          })
        : compound.components;

    var parentSelector = compound.components.first;
    if (parentSelector is ParentSelector) {
      if (compound.components.length == 1 && parentSelector.suffix == null) {
        return parent.components;
      }
    } else {
      return [
        new ComplexSelector([new CompoundSelector(resolvedMembers)])
      ];
    }

    return parent.components.map((complex) {
      var lastComponent = complex.components.last;
      if (lastComponent is! CompoundSelector) {
        throw new SassScriptException(
            'Parent "$complex" is incompatible with this selector.');
      }

      var last = lastComponent as CompoundSelector;
      var suffix = (compound.components.first as ParentSelector).suffix;
      if (suffix != null) {
        last = new CompoundSelector(
            last.components.take(last.components.length - 1).toList()
              ..add(last.components.last.addSuffix(suffix))
              ..addAll(resolvedMembers.skip(1)));
      } else {
        last = new CompoundSelector(
            last.components.toList()..addAll(resolvedMembers.skip(1)));
      }

      return new ComplexSelector(
          complex.components.take(complex.components.length - 1).toList()
            ..add(last),
          lineBreak: complex.lineBreak);
    });
  }

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly additional elements.
  bool isSuperselector(SelectorList other) =>
      listIsSuperslector(components, other.components);

  int get hashCode => listHash(components);

  bool operator ==(other) =>
      other is SelectorList && listEquals(components, other.components);
}
