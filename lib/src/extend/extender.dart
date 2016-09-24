// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../ast/sass.dart';
import '../exception.dart';
import 'source.dart';
import 'functions.dart';

class Extender {
  /// A map from all simple selectors in the stylesheet to the rules that
  /// contain them.
  ///
  /// This is used to find which rules an `@extend` applies to.
  final _selectors = <SimpleSelector, Set<CssStyleRule>>{};

  final _extensions = <SimpleSelector, Set<ExtendSource>>{};

  final _sources = new Expando<ComplexSelector>();

  static SelectorList extend(
          SelectorList selector, SelectorList source, SimpleSelector target) =>
      new Extender()._extendList(
          selector, {target: new Set()..add(new ExtendSource(source, null))});

  static SelectorList replace(
          SelectorList selector, SelectorList source, SimpleSelector target) =>
      new Extender()._extendList(
          selector, {target: new Set()..add(new ExtendSource(source, null))},
          replace: true);

  CssStyleRule addSelector(CssValue<SelectorList> selector, FileSpan span) {
    for (var complex in selector.value.components) {
      for (var component in complex.components) {
        if (component is CompoundSelector) {
          for (var simple in component.components) {
            _sources[simple] = complex;
          }
        }
      }
    }

    if (_extensions.isNotEmpty) {
      selector =
          new CssValue(_extendList(selector.value, _extensions), selector.span);
    }
    var rule = new CssStyleRule(selector, span);
    _registerSelector(selector.value, rule);

    return rule;
  }

  void _registerSelector(SelectorList list, CssStyleRule rule) {
    for (var complex in list.components) {
      for (var component in complex.components) {
        if (component is CompoundSelector) {
          for (var simple in component.components) {
            _selectors.putIfAbsent(simple, () => new Set()).add(rule);

            if (simple is PseudoSelector && simple.selector != null) {
              _registerSelector(simple.selector, rule);
            }
          }
        }
      }
    }
  }

  void addExtension(
      SelectorList sourceList, SimpleSelector target, ExtendRule extend) {
    var source = new ExtendSource(sourceList, extend.span);
    source.isUsed = extend.isOptional;
    _extensions.putIfAbsent(target, () => new Set()).add(source);

    var rules = _selectors[target];
    if (rules == null) return;

    var extensions = {target: new Set()..add(source)};
    for (var rule in rules) {
      var list = rule.selector.value;
      rule.selector.value = _extendList(list, extensions);
    }
  }

  void finalize() {
    for (var sources in _extensions.values) {
      for (var source in sources) {
        if (source.isUsed) continue;
        throw new SassException(
            'The target selector was not found.\n'
            'Use "@extend %foo !optional" to avoid this error.',
            source.span);
      }
    }
  }

  SelectorList _extendList(
      SelectorList list, Map<SimpleSelector, Set<ExtendSource>> extensions,
      {bool replace: false}) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    var changed = false;
    List<ComplexSelector> newList;
    for (var i = 0; i < list.components.length; i++) {
      var complex = list.components[i];
      var extended = _extendComplex(complex, extensions, replace: replace);
      if (extended == null) {
        if (changed) newList.add(complex);
      } else {
        if (!changed) newList = list.components.take(i).toList();
        changed = true;
        newList.addAll(extended);
      }
    }
    if (!changed) return list;

    return new SelectorList(newList.where((complex) => complex != null));
  }

  Iterable<ComplexSelector> _extendComplex(ComplexSelector complex,
      Map<SimpleSelector, Set<ExtendSource>> extensions,
      {bool replace: false}) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    var changed = false;
    List<List<ComplexSelector>> extendedNotExpanded;
    for (var i = 0; i < complex.components.length; i++) {
      var component = complex.components[i];
      if (component is CompoundSelector) {
        var extended = _extendCompound(component, extensions, replace: replace);
        if (extended == null) {
          if (changed) {
            extendedNotExpanded.add([
              new ComplexSelector([component])
            ]);
          }
        } else {
          if (!changed) {
            extendedNotExpanded = complex.components
                .take(i)
                .map((component) => [
                      new ComplexSelector([component],
                          lineBreak: complex.lineBreak)
                    ])
                .toList();
          }
          changed = true;
          extendedNotExpanded.add(extended);
        }
      } else {
        if (changed) {
          extendedNotExpanded.add([
            new ComplexSelector([component])
          ]);
        }
      }
    }
    if (!changed) return null;

    return _trim(paths(extendedNotExpanded).map((path) {
      return weave(path.map((complex) => complex.components).toList())
          .map((outputComplex) {
        return new ComplexSelector(outputComplex,
            lineBreak: complex.lineBreak ||
                path.any((inputComplex) => inputComplex.lineBreak));
      });
    }).toList());
  }

  List<ComplexSelector> _extendCompound(CompoundSelector compound,
      Map<SimpleSelector, Set<ExtendSource>> extensions,
      {bool replace: false}) {
    var original = compound;

    List<ComplexSelector> extended;
    for (var i = 0; i < compound.components.length; i++) {
      var simple = compound.components[i];

      var extendedPseudo = simple is PseudoSelector && simple.selector != null
          ? _extendPseudo(simple, extensions, replace: replace)
          : null;

      if (extendedPseudo != null) {
        var simples = new List<SimpleSelector>(
            compound.components.length - 1 + extendedPseudo.length);
        simples.setRange(0, i, compound.components);
        simples.setRange(i, i + extendedPseudo.length, extendedPseudo);
        simples.setRange(
            i + extendedPseudo.length, simples.length, compound.components, i);
        original = new CompoundSelector(simples);
      }

      var sources = extensions[simple];
      if (sources == null) continue;

      var compoundWithoutSimple =
          new List<SimpleSelector>(compound.components.length - 1);
      compoundWithoutSimple.setRange(0, i, compound.components);
      compoundWithoutSimple.setRange(
          i, compound.components.length - 1, compound.components, i);
      for (var source in sources) {
        for (var complex in source.extender.components) {
          var extenderBase = complex.components.last as CompoundSelector;
          var unified = compoundWithoutSimple.isEmpty
              ? extenderBase
              : unifyCompound(extenderBase.components, compoundWithoutSimple);
          if (unified == null) continue;

          extended ??= replace
              ? []
              : [
                  new ComplexSelector([compound])
                ];
          extended.add(new ComplexSelector(
              complex.components.take(complex.components.length - 1).toList()
                ..add(unified),
              lineBreak: complex.lineBreak));
          source.isUsed = true;
        }
      }
    }

    if (extended == null) {
      return identical(original, compound)
          ? null
          : [
              new ComplexSelector([original])
            ];
    } else if (!identical(original, compound)) {
      if (replace) {
        extended.insert(0, new ComplexSelector([original]));
      } else {
        extended[0] = new ComplexSelector([original]);
      }
    }

    return extended;
  }

  List<PseudoSelector> _extendPseudo(
      PseudoSelector pseudo, Map<SimpleSelector, Set<ExtendSource>> extensions,
      {bool replace: false}) {
    // TODO: avoid recursive loops when extending.
    var extended = _extendList(pseudo.selector, extensions, replace: replace);
    if (extended == null) return null;

    // TODO: what do we do about placeholders in the selector? If we just
    // eliminate them here, what happens to future extends?

    // For `:not()`, we usually want to get rid of any complex selectors because
    // that will cause the selector to fail to parse on all browsers at time of
    // writing. We can keep them if either the original selector had a complex
    // selector, or the result of extending has only complex selectors, because
    // either way we aren't breaking anything that isn't already broken.
    Iterable<ComplexSelector> complexes = extended.components;
    if (pseudo.normalizedName == "not" &&
        !pseudo.selector.components
            .any((complex) => complex.components.length > 1) &&
        extended.components.any((complex) => complex.components.length == 1)) {
      complexes = extended.components
          .where((complex) => complex.components.length <= 1);
    }

    complexes = complexes.expand((complex) {
      if (complex.components.length != 1) return [complex];
      if (complex.components.first is! CompoundSelector) return [complex];
      var compound = complex.components.first as CompoundSelector;
      if (compound.components.length != 1) return [complex];
      if (compound.components.first is! PseudoSelector) return [complex];
      var innerPseudo = compound.components.first as PseudoSelector;
      if (innerPseudo.selector == null) return [complex];

      switch (pseudo.normalizedName) {
        case 'not':
          // In theory, if there's a `:not` nested within another `:not`, the
          // inner `:not`'s contents should be unified with the return value.
          // For example, if `:not(.foo)` extends `.bar`, `:not(.bar)` should
          // become `.foo:not(.bar)`. However, this is a narrow edge case and
          // supporting it properly would make this code and the code calling it
          // a lot more complicated, so it's not supported for now.
          if (innerPseudo.normalizedName != 'matches') return [];
          return innerPseudo.selector.components;

        case 'matches':
        case 'any':
        case 'current':
        case 'nth-child':
        case 'nth-last-child':
          // As above, we could theoretically support :not within :matches, but
          // doing so would require this method and its callers to handle much
          // more complex cases that likely aren't worth the pain.
          if (innerPseudo.name != pseudo.name) return [];
          if (innerPseudo.argument != pseudo.argument) return [];
          return innerPseudo.selector.components;

        case 'has':
        case 'host':
        case 'host-context':
          // We can't expand nested selectors here, because each layer adds an
          // additional layer of semantics. For example, `:has(:has(img))`
          // doesn't match `<div><img></div>` but `:has(img)` does.
          return [complex];

        default:
          return [];
      }
    });

    // Older browsers support `:not`, but only with a single complex selector.
    // In order to support those browsers, we break up the contents of a `:not`
    // unless it originally contained a selector list.
    if (pseudo.normalizedName == 'not' &&
        pseudo.selector.components.length == 1) {
      return complexes
          .map((complex) => pseudo.withSelector(new SelectorList([complex])))
          .toList();
    } else {
      return [pseudo.withSelector(new SelectorList(complexes))];
    }
  }

  List<ComplexSelector> _trim(List<List<ComplexSelector>> lists) {
    // Avoid truly horrific quadratic behavior.
    //
    // TODO(nweiz): I think there may be a way to get perfect trimming without
    // going quadratic by building some sort of trie-like data structure that
    // can be used to look up superselectors.
    if (lists.length > 100) return lists.expand((selectors) => selectors);

    // This is n² on the sequences, but only comparing between separate
    // sequences should limit the quadratic behavior.
    var result = <ComplexSelector>[];
    for (var i = 0; i < lists.length; i++) {
      for (var complex1 in lists[i]) {
        // The maximum specificity of the sources that caused [complex1] to be
        // generated. In order for [complex1] to be removed, there must be
        // another selector that's a superselector of it *and* that has
        // specificity greater or equal to this.
        var maxSpecificity = 0;
        for (var component in complex1.components) {
          if (component is CompoundSelector) {
            for (var simple in component.components) {
              var source = _sources[simple];
              if (source == null) continue;
              maxSpecificity = math.max(maxSpecificity, source.maxSpecificity);
            }
          }
        }

        // Look in [result] rather than [lists] for selectors before [i]. This
        // ensures that we aren't comparing against a selector that's already
        // been trimmed, and thus that if there are two identical selectors only
        // one is trimmed.
        if (result.any((complex2) =>
            complex2.minSpecificity >= maxSpecificity &&
            complex2.isSuperselector(complex1))) {
          continue;
        }

        // We intentionally don't compare [complex1] against other selectors in
        // `lists[i]`, since they come from the same source.
        if (lists.skip(i + 1).any((list) => list.any((complex2) =>
            complex2.minSpecificity >= maxSpecificity &&
            complex2.isSuperselector(complex1)))) {
          continue;
        }

        result.add(complex1);
      }
    }

    return result;
  }
}
