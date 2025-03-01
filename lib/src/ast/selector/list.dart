// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../exception.dart';
import '../../extend/functions.dart';
import '../../interpolation_map.dart';
import '../../parse/selector.dart';
import '../../utils.dart';
import '../../util/iterable.dart';
import '../../util/span.dart';
import '../../value.dart';
import '../../visitor/interface/selector.dart';
import '../../visitor/selector_search.dart';
import '../css/value.dart';
import '../selector.dart';

/// A selector list.
///
/// A selector list is composed of [ComplexSelector]s. It matches any element
/// that matches any of the component selectors.
///
/// {@category AST}
/// {@category Parsing}
final class SelectorList extends Selector {
  /// The components of this selector.
  ///
  /// This is never empty.
  final List<ComplexSelector> components;

  /// Returns a SassScript list that represents this selector.
  ///
  /// This has the same format as a list returned by `selector-parse()`.
  SassList get asSassList {
    return SassList(
      components.map((complex) {
        return SassList([
          if (complex.leadingCombinator case var combinator?)
            SassString(combinator.toString(), quotes: false),
          for (var component in complex.components) ...[
            SassString(component.selector.toString(), quotes: false),
            if (component.combinator case var combinator?)
              SassString(combinator.toString(), quotes: false),
          ],
        ], ListSeparator.space);
      }),
      ListSeparator.comma,
    );
  }

  /// Whether `this` is a CSS selector that's valid on its own at the root of
  /// the CSS document.
  ///
  /// Selectors with leading or trailing combinators are *not* stand-alone.
  bool get isStandAlone => components.every((complex) => complex.isStandAlone);

  /// Whether `this` is a valid [relative selector].
  ///
  /// This allows leading combinators but not trailing combinators.
  ///
  /// [relative selector]: https://www.w3.org/TR/selectors-4/#relative-selector
  bool get isRelative => components.every((complex) => complex.isRelative);

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
    if (allowLeadingCombinator && allowTrailingCombinator) return;
    for (var complex in components) {
      complex.assertValid(
          name: name,
          allowLeadingCombinator: allowLeadingCombinator,
          allowTrailingCombinator: allowTrailingCombinator);
    }
  }

  SelectorList(Iterable<ComplexSelector> components, super.span)
      : components = List.unmodifiable(components) {
    if (this.components.isEmpty) {
      throw ArgumentError("components may not be empty.");
    }
  }

  /// Parses a selector list from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes. If
  /// [allowParent] is false, this doesn't allow [ParentSelector]s. If
  /// [plainCss] is true, this parses the selector as plain CSS rather than
  /// unresolved Sass.
  ///
  /// If passed, [interpolationMap] maps the text of [contents] back to the
  /// original location of the selector in the source file.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory SelectorList.parse(
    String contents, {
    Object? url,
    InterpolationMap? interpolationMap,
    bool allowParent = true,
    bool plainCss = false,
  }) =>
      SelectorParser(
        contents,
        url: url,
        interpolationMap: interpolationMap,
        allowParent: allowParent,
        plainCss: plainCss,
      ).parse();

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitSelectorList(this);

  /// Returns a [SelectorList] that matches only elements that are matched by
  /// both this and [other].
  ///
  /// If no such list can be produced, returns `null`.
  SelectorList? unify(SelectorList other) {
    var contents = [
      for (var complex1 in components)
        for (var complex2 in other.components)
          ...?unifyComplex([complex1, complex2], complex1.span),
    ];

    return contents.isEmpty ? null : SelectorList(contents, span);
  }

  /// Returns a new selector list that represents `this` nested within [parent].
  ///
  /// By default, this replaces [ParentSelector]s in `this` with [parent]. If
  /// [preserveParentSelectors] is true, this instead preserves those selectors
  /// as parent selectors.
  ///
  /// If [implicitParent] is true, this prepends [parent] to any
  /// [ComplexSelector]s in this that don't contain explicit [ParentSelector]s,
  /// or to _all_ [ComplexSelector]s if [preserveParentSelectors] is true.
  ///
  /// The given [parent] may be `null`, indicating that this has no parents. If
  /// so, this list is returned as-is if it doesn't contain any explicit
  /// [ParentSelector]s or if [preserveParentSelectors] is true. Otherwise, this
  /// throws a [SassScriptException].
  SelectorList nestWithin(
    SelectorList? parent, {
    bool implicitParent = true,
    bool preserveParentSelectors = false,
  }) {
    if (parent == null) {
      if (preserveParentSelectors) return this;
      var parentSelector = accept(const _ParentSelectorVisitor());
      if (parentSelector == null) return this;
      throw SassException(
        'Top-level selectors may not contain the parent selector "&".',
        parentSelector.span,
      );
    }

    return SelectorList(
      flattenVertically(
        components.map((complex) {
          if (preserveParentSelectors || !_containsParentSelector(complex)) {
            if (!implicitParent) return [complex];
            return [
              for (var parentComplex in parent.components)
                if (parentComplex.concatenate(complex, complex.span)
                    case var newComplex?)
                  newComplex
                else
                  throw MultiSpanSassException(
                    'The selector "$parentComplex $complex" is invalid CSS.',
                    complex.span.trimRight(),
                    "inner selector",
                    {parentComplex.span.trimRight(): "outer selector"},
                  ),
            ];
          }

          var newComplexes = <ComplexSelector>[];
          for (var component in complex.components) {
            var resolved = _nestWithinCompound(component, parent);
            if (resolved == null) {
              if (newComplexes.isEmpty) {
                newComplexes.add(
                  ComplexSelector(
                    [component],
                    complex.span.trimRight(),
                    leadingCombinator: complex.leadingCombinator,
                    lineBreak: false,
                  ),
                );
              } else {
                for (var i = 0; i < newComplexes.length; i++) {
                  newComplexes[i] = newComplexes[i].withAdditionalComponent(
                    component,
                    complex.span,
                  );
                }
              }
            } else if (newComplexes.isEmpty) {
              newComplexes.addAll(switch (complex.leadingCombinator) {
                null => resolved,
                var leadingCombinator => [
                    for (var resolvedComplex in resolved)
                      if (resolvedComplex.prependCombinator(leadingCombinator)
                          case var newResolved?)
                        newResolved
                      else
                        throw MultiSpanSassException(
                          'The selector "$leadingCombinator $resolvedComplex" is '
                              'invalid CSS.',
                          complex.span.trimRight(),
                          "inner selector",
                          {parent.span.trimRight(): "outer selector"},
                        ),
                  ],
              });
            } else {
              newComplexes = [
                for (var newComplex in newComplexes)
                  for (var resolvedComplex in resolved)
                    if (newComplex.concatenate(resolvedComplex, newComplex.span)
                        case var newResolved?)
                      newResolved
                    else
                      throw MultiSpanSassException(
                        'The selector "$newComplex $resolvedComplex" is invalid '
                            'CSS.',
                        resolvedComplex.span.trimRight(),
                        "inner selector",
                        {newComplex.span.trimRight(): "outer selector"},
                      ),
              ];
            }
          }

          return newComplexes;
        }),
      ),
      span,
    );
  }

  /// Returns a new selector list based on [component] with all
  /// [ParentSelector]s replaced with [parent].
  ///
  /// Returns `null` if [component] doesn't contain any [ParentSelector]s.
  Iterable<ComplexSelector>? _nestWithinCompound(
    ComplexSelectorComponent component,
    SelectorList parent,
  ) {
    var simples = component.selector.components;
    var containsSelectorPseudo = simples.any((simple) {
      if (simple is! PseudoSelector) return false;
      var selector = simple.selector;
      return selector != null && _containsParentSelector(selector);
    });
    if (!containsSelectorPseudo && simples.first is! ParentSelector) {
      return null;
    }

    var resolvedSimples = containsSelectorPseudo
        ? simples.map((simple) {
            if (simple
                case PseudoSelector(
                  :var selector?,
                ) when _containsParentSelector(selector)) {
              var nested = selector.nestWithin(parent, implicitParent: false);
              var result = simple.withSelector(nested);
              if (result != null) return result;

              var invalid = simple.toString().replaceFirst(
                    RegExp(r"\(.*\)"),
                    "($nested)",
                  );
              throw MultiSpanSassException(
                  'The selector "$invalid" is invalid CSS.',
                  simple.accept(_ParentSelectorVisitor())!.span.trimRight(),
                  "parent selector",
                  {parent.span.trimRight(): "outer selector"});
            } else {
              return simple;
            }
          }).toList()
        : simples;

    var parentSelector = simples.first;
    if (parentSelector is! ParentSelector) {
      return [
        ComplexSelector([
          ComplexSelectorComponent(
            CompoundSelector(resolvedSimples, component.selector.span),
            component.span,
            combinator: component.combinator,
          ),
        ], component.span),
      ];
    } else if (simples.length == 1 && parentSelector.suffix == null) {
      return switch (parent.withAdditionalCombinator(component.combinator)) {
        var list? => list.components,
        _ => throw MultiSpanSassException(
            'The selector "${parent.components.first} ${component.combinator}" '
                'is invalid CSS.',
            parentSelector.span,
            "parent selector",
            {parent.span.trimRight(): "outer selector"},
          )
      };
    }

    return parent.components.map((complex) {
      var lastComponent = complex.components.last;
      if (lastComponent.combinator != null) {
        throw MultiSpanSassException(
          'Selector "$complex" can\'t be used as a parent in a compound '
              'selector.',
          lastComponent.span.trimRight(),
          "outer selector",
          {parentSelector.span: "parent selector"},
        );
      }

      try {
        var suffix = parentSelector.suffix;
        var lastSimples = lastComponent.selector.components;
        var last = CompoundSelector(
          suffix == null
              ? [...lastSimples, ...resolvedSimples.skip(1)]
              : [
                  ...lastSimples.exceptLast,
                  lastSimples.last.addSuffix(suffix),
                  ...resolvedSimples.skip(1),
                ],
          component.selector.span,
        );

        return ComplexSelector(
          [
            ...complex.components.exceptLast,
            ComplexSelectorComponent(
              last,
              component.span,
              combinator: component.combinator,
            ),
          ],
          component.span,
          leadingCombinator: complex.leadingCombinator,
          lineBreak: complex.lineBreak,
        );
      } on SassException catch (error, stackTrace) {
        throwWithTrace(
          error
              .withAdditionalSpan(
                  lastComponent.span.trimRight(), "outer selector")
              .withAdditionalSpan(parentSelector.span, "parent selector"),
          error,
          stackTrace,
        );
      }
    });
  }

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly additional elements.
  bool isSuperselector(SelectorList other) =>
      listIsSuperselector(components, other.components);

  /// Returns a copy of `this` with [combinator] added to the end of each
  /// complex selector in [components].
  ///
  /// Returns `null` if this would produce an invalid selector.
  ///
  /// @nodoc
  @internal
  SelectorList? withAdditionalCombinator(CssValue<Combinator>? combinator) {
    if (combinator == null) return this;
    var newComponents = [
      for (var complex in components)
        if (complex.withAdditionalCombinator(combinator) case var newComplex?)
          newComplex,
    ];
    return newComponents.isEmpty ? null : SelectorList(newComponents, span);
  }

  int get hashCode => listHash(components);

  bool operator ==(Object other) =>
      other is SelectorList && listEquals(components, other.components);
}

/// Returns whether [selector] recursively contains a parent selector.
bool _containsParentSelector(Selector selector) =>
    selector.accept(const _ParentSelectorVisitor()) != null;

/// A visitor for finding the first [ParentSelector] in a given selector.
class _ParentSelectorVisitor with SelectorSearchVisitor<ParentSelector> {
  const _ParentSelectorVisitor();

  ParentSelector visitParentSelector(ParentSelector selector) => selector;
}
