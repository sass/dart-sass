// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../utils.dart';
import 'functions.dart';

class Extender {
  /// A map from all simple selectors in the stylesheet to the rules that
  /// contain them.
  ///
  /// This is used to find which rules an `@extend` applies to.
  final _selectors = <SimpleSelector, Set<CssStyleRule>>{};

  final _extensions = <SimpleSelector, Set<SelectorList>>{};

  final _sources = new Expando<ComplexSelector>();

  CssStyleRule addSelector(
      CssValue<SelectorList> selectorValue, FileSpan span) {
    var selector = selectorValue.value;
    for (var complex in selector.components) {
      for (var component in complex.components) {
        if (component is CompoundSelector) {
          for (var simple in component.components) {
            _sources[simple] = complex;
          }
        }
      }
    }

    if (_extensions.isNotEmpty) selector = _extendList(selector, _extensions);
    var rule = new CssStyleRule(selectorValue, span);

    for (var complex in selector.components) {
      for (var component in complex.components) {
        if (component is CompoundSelector) {
          for (var simple in component.components) {
            _selectors.putIfAbsent(simple, () => new Set()).add(rule);
          }
        }
      }
    }

    return rule;
  }

  void addExtension(SelectorList extender, SimpleSelector target) {
    _extensions.putIfAbsent(target, () => new Set()).add(extender);

    var rules = _selectors[target];
    if (rules == null) return;

    var extensions = {
      target: new Set.from([extender])
    };
    for (var rule in rules) {
      var list = rule.selector.value;
      rule.selector.value = _extendList(list, extensions);
    }
  }

  SelectorList _extendList(
      SelectorList list, Map<SimpleSelector, Set<SelectorList>> extensions) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    var changed = false;
    List<ComplexSelector> newList;
    for (var i = 0; i < list.components.length; i++) {
      var complex = list.components[i];
      var extended = _extendComplex(complex, extensions);
      if (extended == null) {
        if (changed) newList.add(complex);
      } else {
        if (!changed) newList = list.components.take(i).toList();
        changed = true;
        newList.addAll(extended);
      }
    }
    if (!changed) return list;

    // TODO: compute new line breaks
    return new SelectorList(newList.where((complex) => complex != null));
  }

  Iterable<ComplexSelector> _extendComplex(ComplexSelector complex,
      Map<SimpleSelector, Set<SelectorList>> extensions) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    var changed = false;
    List<List<List<ComplexSelectorComponent>>> extendedNotExpanded;
    for (var i = 0; i < complex.components.length; i++) {
      var component = complex.components[i];
      if (component is CompoundSelector) {
        var extended = _extendCompound(component, extensions);
        // TODO: follow the first law of extend (https://github.com/sass/sass/blob/7774aa3/lib/sass/selector/sequence.rb#L114-L118)
        if (extended == null) {
          if (changed)
            extendedNotExpanded.add([
              [component]
            ]);
        } else {
          if (!changed) {
            extendedNotExpanded = complex.components
                .take(i)
                .map((component) => [
                      [component]
                    ])
                .toList();
          }
          changed = true;
          extendedNotExpanded.add(extended);
        }
      } else {
        if (changed)
          extendedNotExpanded.add([
            [component]
          ]);
      }
    }
    if (!changed) return null;

    // TODO: preserve line breaks
    var weaves =
        _paths(extendedNotExpanded).map((path) => _weave(path)).toList();
    return _trim(weaves).map((complex) => new ComplexSelector(complex));
  }

  List<List<ComplexSelectorComponent>> _extendCompound(
      CompoundSelector compound,
      Map<SimpleSelector, Set<SelectorList>> extensions) {
    var changed = false;
    List<List<ComplexSelectorComponent>> extended;
    for (var i = 0; i < compound.components.length; i++) {
      var simple = compound.components[i];

      // TODO: handle extending into pseudo selectors, extend failures

      var extenders = extensions[simple];
      if (extenders == null) continue;

      var compoundWithoutSimple = compound.components.toList()..removeAt(i);
      for (var list in extenders) {
        for (var complex in list.components) {
          var extenderBase = complex.components.last as CompoundSelector;
          var unified = compoundWithoutSimple.isEmpty
              ? extenderBase
              : _unifyCompound(extenderBase.components, compoundWithoutSimple);
          if (unified == null) continue;

          if (!changed)
            extended = [
              [compound]
            ];
          changed = true;
          extended.add(complex.components
              .take(complex.components.length - 1)
              .toList()..add(unified));
        }
      }
    }

    return extended;
  }

  List<List<ComplexSelectorComponent>> _weave(
      List<List<ComplexSelectorComponent>> complexes) {
    var prefixes = [complexes.first];

    for (var complex in complexes.skip(1)) {
      if (complex.isEmpty) continue;

      var target = complex.last;
      if (complex.length == 1) {
        for (var prefix in prefixes) {
          prefix.add(target);
        }
        continue;
      }

      var parents = complex.take(complex.length - 1).toList();
      var newPrefixes = <List<ComplexSelectorComponent>>[];
      for (var prefix in prefixes) {
        var parentPrefixes = _weaveParents(prefix, parents);
        if (parentPrefixes == null) continue;

        for (var parentPrefix in parentPrefixes) {
          newPrefixes.add(parentPrefix..add(target));
        }
      }
      prefixes = newPrefixes;
    }

    return prefixes;
  }

  List<List<ComplexSelectorComponent>> _weaveParents(
      List<ComplexSelectorComponent> parents1,
      List<ComplexSelectorComponent> parents2) {
    var queue1 = new Queue<ComplexSelectorComponent>.from(parents1);
    var queue2 = new Queue<ComplexSelectorComponent>.from(parents2);

    var initialCombinator = _mergeInitialCombinators(queue1, queue2);
    if (initialCombinator == null) return null;
    var finalCombinator = _mergeFinalCombinators(queue1, queue2);
    if (finalCombinator == null) return null;

    // Make sure there's at most one `:root` in the output.
    var root1 = _firstIfRoot(queue1);
    var root2 = _firstIfRoot(queue2);
    if (root1 != null && root2 != null) {
      var root = _unifyCompound(root1.components, root2.components);
      if (root == null) return null;
      queue1.addFirst(root);
      queue2.addFirst(root);
    } else if (root1 != null) {
      queue2.addFirst(root1);
    } else if (root2 != null) {
      queue1.addFirst(root2);
    }

    var groups1 = _groupSelectors(queue1);
    var groups2 = _groupSelectors(queue2);
    var lcs = longestCommonSubsequence/*<List<ComplexSelectorComponent>>*/(
        groups1, groups2, select: (group1, group2) {
      if (listEquals(group1, group2)) return group1;
      if (group1.first is! CompoundSelector ||
          group2.first is! CompoundSelector) {
        return null;
      }
      if (complexIsParentSuperselector(group1, group2)) return group2;
      if (complexIsParentSuperselector(group2, group1)) return group1;
      if (!_mustUnify(group1, group2)) return null;

      var unified = _unifyComplex(group1, group2);
      if (unified == null) return null;
      if (unified.length > 1) return null;
      return unified.first;
    });

    var choices = [
      <List<ComplexSelectorComponent>>[initialCombinator]
    ];
    for (var group in lcs) {
      choices.add(_chunks/*<List<ComplexSelectorComponent>>*/(groups1, groups2,
              (sequence) => complexIsParentSuperselector(sequence.first, group))
          .map((chunk) => chunk.expand((group) => group)));
      choices.add([group]);
      groups1.removeFirst();
      groups2.removeFirst();
    }
    choices.add(_chunks(groups1, groups2, (sequence) => sequence.isEmpty)
        .map((chunk) => chunk.expand((group) => group)));
    choices.addAll(finalCombinator);

    return _paths(choices.where((choice) => choice.isNotEmpty))
        .map((path) => path.expand((group) => group));
  }

  CompoundSelector _firstIfRoot(Queue<ComplexSelectorComponent> queue) {
    var first = queue.first as CompoundSelector;
    if (!_hasRoot(first)) return null;

    queue.removeFirst();
    return first;
  }

  List<Combinator> _mergeInitialCombinators(
      Queue<ComplexSelectorComponent> components1,
      Queue<ComplexSelectorComponent> components2) {
    var combinators1 = <Combinator>[];
    while (components1.first is Combinator) {
      combinators1.add(components1.removeFirst() as Combinator);
    }

    var combinators2 = <Combinator>[];
    while (components2.first is Combinator) {
      combinators2.add(components2.removeFirst() as Combinator);
    }

    // If neither sequence of combinators is a subsequence of the other, they
    // cannot be merged successfully.
    var lcs = longestCommonSubsequence(combinators1, combinators2);
    if (listEquals(lcs, combinators1)) return combinators2;
    if (listEquals(lcs, combinators2)) return combinators1;
    return null;
  }

  List<List<List<ComplexSelectorComponent>>> _mergeFinalCombinators(
      Queue<ComplexSelectorComponent> components1,
      Queue<ComplexSelectorComponent> components2,
      [QueueList<List<List<ComplexSelectorComponent>>> result]) {
    result ??= new QueueList();
    if ((components1.isEmpty || components1.last is! Combinator) &&
        (components2.isEmpty || components2.last is! Combinator)) {
      return result;
    }

    var combinators1 = <Combinator>[];
    while (components1.last is Combinator) {
      combinators1.add(components1.last as Combinator);
    }

    var combinators2 = <Combinator>[];
    while (components2.last is Combinator) {
      combinators2.add(components2.last as Combinator);
    }

    if (combinators1.length > 1 || combinators2.length > 1) {
      // If there are multiple combinators, something hacky's going on. If one
      // is a supersequence of the other, use that, otherwise give up.
      var lcs = longestCommonSubsequence(combinators1, combinators2);
      if (listEquals(lcs, combinators1)) {
        result.addAll([new List.from(combinators2.reversed)]);
      } else if (listEquals(lcs, combinators2)) {
        result.addAll([new List.from(combinators1.reversed)]);
      }
      return result;
    }

    // This code looks complicated, but it's actually just a bunch of special
    // cases for interactions between different combinators.
    var combinator1 = combinators1.isEmpty ? null : combinators1.first;
    var combinator2 = combinators2.isEmpty ? null : combinators2.first;
    if (combinator1 != null && combinator2 != null) {
      var compound1 = components1.removeLast() as CompoundSelector;
      var compound2 = components2.removeLast() as CompoundSelector;

      if (combinator1 == Combinator.followingSibling &&
          combinator2 == Combinator.followingSibling) {
        if (compound1.isSuperselector(compound2)) {
          result.addFirst([
            [compound2, Combinator.followingSibling]
          ]);
        } else if (compound2.isSuperselector(compound1)) {
          result.addFirst([
            [compound1, Combinator.followingSibling]
          ]);
        } else {
          var choices = [
            [
              compound1,
              Combinator.followingSibling,
              compound2,
              Combinator.followingSibling
            ],
            [
              compound2,
              Combinator.followingSibling,
              compound1,
              Combinator.followingSibling
            ]
          ];

          var unified =
              _unifyCompound(compound1.components, compound2.components);
          if (unified != null) {
            choices.add([unified, Combinator.followingSibling]);
          }

          result.addFirst(choices);
        }
      } else if ((combinator1 == Combinator.followingSibling &&
              combinator2 == Combinator.nextSibling) ||
          (combinator1 == Combinator.nextSibling &&
              combinator2 == Combinator.followingSibling)) {
        var followingSiblingSelector =
            combinator1 == Combinator.followingSibling ? compound1 : compound2;
        var nextSiblingSelector =
            combinator1 == Combinator.followingSibling ? compound2 : compound1;

        if (followingSiblingSelector.isSuperselector(nextSiblingSelector)) {
          result.addFirst([
            [nextSiblingSelector, Combinator.nextSibling]
          ]);
        } else {
          var choices = [
            [
              followingSiblingSelector,
              Combinator.followingSibling,
              nextSiblingSelector,
              Combinator.nextSibling
            ]
          ];

          var unified =
              _unifyCompound(compound1.components, compound2.components);
          if (unified != null) choices.add([unified, Combinator.nextSibling]);
          result.addFirst(choices);
        }
      } else if (combinator1 == Combinator.child &&
          (combinator2 == Combinator.nextSibling ||
              combinator2 == Combinator.followingSibling)) {
        result.addFirst([
          [compound2, combinator2]
        ]);
        components1..add(compound1)..add(Combinator.child);
      } else if (combinator2 == Combinator.child &&
          (combinator1 == Combinator.nextSibling ||
              combinator1 == Combinator.followingSibling)) {
        result.addFirst([
          [compound2, combinator2]
        ]);
        components1..add(compound1)..add(Combinator.child);
      } else if (combinator1 == combinator2) {
        var unified =
            _unifyCompound(compound1.components, compound2.components);
        if (unified == null) return null;
        result.addFirst([
          [unified, combinator1]
        ]);
      } else {
        return null;
      }

      return _mergeFinalCombinators(components1, components2, result);
    } else if (combinator1 != null) {
      if (combinator1 == Combinator.child &&
          components2.isNotEmpty &&
          (components2.last as CompoundSelector)
              .isSuperselector(components1.last)) {
        components2.removeLast();
      }
      result.addFirst([
        [components1.removeLast(), combinator1]
      ]);
      return _mergeFinalCombinators(components1, components2, result);
    } else {
      assert(combinator1 != null);
      if (combinator2 == Combinator.child &&
          components1.isNotEmpty &&
          (components1.last as CompoundSelector)
              .isSuperselector(components2.last)) {
        components1.removeLast();
      }
      result.addFirst([
        [components2.removeLast(), combinator2]
      ]);
      return _mergeFinalCombinators(components1, components2, result);
    }
  }

  bool _mustUnify(List<ComplexSelectorComponent> complex1,
      List<ComplexSelectorComponent> complex2) {
    var uniqueSelectors = new Set<SimpleSelector>();
    for (var component in complex1) {
      if (component is CompoundSelector) {
        uniqueSelectors.addAll(component.components.where(_isUnique));
      }
    }
    if (uniqueSelectors.isEmpty) return false;

    return complex2.any((component) =>
        component is CompoundSelector &&
        component.components.any(
            (simple) => _isUnique(simple) && uniqueSelectors.contains(simple)));
  }

  bool _isUnique(SimpleSelector simple) =>
      simple is IDSelector ||
      (simple is PseudoSelector && simple.type == PseudoType.element);

  List<List/*<T>*/ > _chunks/*<T>*/(
      Queue/*<T>*/ queue1, Queue/*<T>*/ queue2, bool done(Queue/*<T>*/ queue)) {
    var chunk1 = /*<T>*/ [];
    while (!done(queue1)) {
      chunk1.add(queue1.removeFirst());
    }

    var chunk2 = /*<T>*/ [];
    while (!done(queue2)) {
      chunk2.add(queue2.removeFirst());
    }

    if (chunk1.isEmpty && chunk2.isEmpty) return [];
    if (chunk1.isEmpty) return [chunk2];
    if (chunk2.isEmpty) return [chunk1];
    return [chunk1.toList()..addAll(chunk2), chunk2..addAll(chunk1)];
  }

  List<List/*<T>*/ > _paths/*<T>*/(Iterable<List/*<T>*/ > choices) =>
      choices.fold(
          [[]],
          (paths, choice) => choice
              .expand(
                  (option) => paths.map((path) => path.toList()..add(option)))
              .toList());

  QueueList<List<ComplexSelectorComponent>> _groupSelectors(
      Iterable<ComplexSelectorComponent> complex) {
    var groups = new QueueList<List<ComplexSelectorComponent>>();
    var iterator = complex.iterator;
    while (iterator.moveNext()) {
      var group = <ComplexSelectorComponent>[];
      do {
        group.add(iterator.current);
      } while ((iterator.current is Combinator || group.last is Combinator) &&
          iterator.moveNext());
      groups.add(group);
    }
    return groups;
  }

  List<List<ComplexSelectorComponent>> _trim(
      List<List<List<ComplexSelectorComponent>>> lists) {
    // Avoid truly horrific quadratic behavior.
    //
    // TODO(nweiz): I think there may be a way to get perfect trimming without
    // going quadratic by building some sort of trie-like data structure that
    // can be used to look up superselectors.
    if (lists.length > 100) return lists.expand((selectors) => selectors);

    // This is n² on the sequences, but only comparing between separate
    // sequences should limit the quadratic behavior.
    var result = <List<ComplexSelectorComponent>>[];
    for (var i = 0; i < lists.length; i++) {
      for (var complex1 in lists[i]) {
        // The maximum specificity of the sources that caused [complex1] to be
        // generated. In order for [complex1] to be removed, there must be
        // another selector that's a superselector of it *and* that has
        // specificity greater or equal to this.
        var maxSpecificity = 0;
        for (var component in complex1) {
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
            _complexMinSpecificity(complex2) >= maxSpecificity &&
            complexIsSuperselector(complex2, complex1))) {
          continue;
        }

        // We intentionally don't compare [complex1] against other selectors in
        // `lists[i]`, since they come from the same source.
        if (lists.skip(i + 1).any((list) => list.any((complex2) =>
            _complexMinSpecificity(complex2) >= maxSpecificity &&
            complexIsSuperselector(complex2, complex1)))) {
          continue;
        }

        result.add(complex1);
      }
    }

    return result;
  }

  int _complexMinSpecificity(Iterable<ComplexSelectorComponent> complex) {
    var result = 0;
    for (var component in complex) {
      if (component is CompoundSelector) {
        result += component.minSpecificity;
      }
    }
    return result;
  }

  bool _hasRoot(CompoundSelector compound) =>
      compound.components.any((simple) =>
          simple is PseudoSelector &&
          simple.type == PseudoType.klass &&
          simple.normalizedName == 'root');

  List<List<ComplexSelectorComponent>> _unifyComplex(
      List<ComplexSelectorComponent> complex1,
      List<ComplexSelectorComponent> complex2) {
    var base1 = complex1.last;
    var base2 = complex2.last;
    if (base1 is CompoundSelector && base2 is CompoundSelector) {
      var unified = _unifyCompound(base2.components, base1.components);
      if (unified == null) return null;

      return _weave([
        complex1.take(complex1.length - 1).toList(),
        complex2.take(complex2.length - 1).toList()..add(unified)
      ]);
    } else {
      return null;
    }
  }

  CompoundSelector _unifyCompound(
      List<SimpleSelector> compound1, List<SimpleSelector> compound2) {
    var result = compound2;
    for (var simple in compound1) {
      result = simple.unify(result);
      if (result == null) return null;
    }

    return new CompoundSelector(result);
  }
}
