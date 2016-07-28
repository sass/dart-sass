// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/selector.dart';

class Extender {
  /// A map from all simple selectors in the stylesheet to the rules that
  /// contain them.
  ///
  /// This is used to find which rules an `@extend` applies to.
  final _selectors = <SimpleSelector, Set<CssStyleRule>>{};

  final _extensions = <SimpleSelector, Set<SelectorList>>{};

  Set<PseudoSelector> _seen;

  CssStyleRule addSelector(SelectorList selector, {FileSpan span}) {
    if (_extensions.isNotEmpty) selector = _extendList(selector);
    var rule = new CssStyleRule(selector, span: span);

    for (var complex in selector.components) {
      for (var maybeCompound in complex.components) {
        if (maybeCompound is CompoundSelector) {
          for (var simple in maybeCompound.components) {
            _selectors.putIfAbsent(simple, () => new Set()).add(rule);
          }
        }
      }
    }

    return rule;
  }

  SelectorList _extendList(SelectorList selector) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    var changed = false;
    List<ComplexSelector> newComponents;
    for (var i = 0; i < selector.components.length; i++) {
      var complex = selector.components[i];
      var extended = _extendComplex(complex);
      if (extended == null) {
        if (changed) newComponents.add(complex);
      } else {
        if (!changed) newComponents = selector.components.take(i).toList();
        changed = true;
        newComponents.addAll(extended);
      }
    }
    if (!changed) return selector;

    // TODO: compute new line breaks
    return new SelectorList(newComponents.where((complex) => complex != null));
  }

  List<ComplexSelector> _extendComplex(ComplexSelector selector) {
    // This could be written more simply using [List.map], but we want to avoid
    // any allocations in the common case where no extends apply.
    var changed = false;
    List<List<List<ComplexSelectorComponent>>> extendedNotExpanded;
    for (var i = 0; i < selector.components.length; i++) {
      var component = selector.components[i];
      if (component is CompoundSelector) {
        var extended = _extendCompound(component);
        // TODO: follow the first law of extend (https://github.com/sass/sass/blob/7774aa3/lib/sass/selector/sequence.rb#L114-L118)
        if (extended == null) {
          if (changed) extendedNotExpanded.add([[component]]);
        } else {
          if (!changed) {
            extendedNotExpanded =
                selector.components.take(i).map((component) => [[component]]);
          }
          changed = true;
          extendedNotExpanded.add(extended);
        }
      } else {
        if (changed) extendedNotExpanded.add([[component]]);
      }
    }
    if (!changed) return null;

    // TODO: preserve line breaks
    var weaves = paths(extendedNotExpanded)
        .map((path) => _weave(path))
        .toList();
    return _trim(weaves).map((components) => new ComplexSelector(components));
  }

  List<List<ComplexSelectorComponent>> _extendCompound(
      CompoundSelector selector) {
    var changed = false;
    List<List<ComplexSelectorComponent>> extended;
    for (var i = 0; i < selector.components.length; i++) {
      var simple = selector.components[i];

      // TODO: handle extending into pseudo selectors, tracking sources, extend
      // failures

      var extenders = _extensions[simple];
      if (extenders == null) continue;

      var componentsWithoutSimple =
          selector.components.toList()..removeAt(i);
      for (var list in extenders) {
        for (var complex in list.components) {
          var compound = complex.members.last as CompoundSelector;
          var unified = _unifyCompound(
              compound.components, componentsWithoutSimple);
          if (unified == null) continue;

          if (!changed) extended = [[selector]];
          changed = true;
          extended.add(compound.members
              .take(compound.members.length - 1)
              .toList()
              ..add(unified));
        }
      }
    }

    return extended;
  }

  List<List<ComplexSelectorComponent>> _weave(
      List<List<ComplexSelectorComponent>> path) {
    var prefixes = [path.first];

    for (var components in path.skip(1)) {
      if (components.isEmpty) continue;

      var target = components.last;
      if (components.length == 1) {
        for (var prefix in prefixes) {
          prefix.add(target);
        }
      }

      var parents = components.take(components.length - 1).toList();
      prefixes = prefixes.expand((prefix) {
        var parentPrefixes = _weaveParents(prefix, parents);
        if (parentPrefixes == null) return const [];
        return parentPrefixes.map((parentPrefix) => parentPrefix.add(target));
      }).toList();
    }

    return prefixes;
  }

  List<List<ComplexSelectorComponent>> _weaveParents(
      List<ComplexSelectorComponent> parents1,
      List<ComplexSelectorComponent> parents2) {
    var queue1 = new Queue.from(parents1);
    var queue2 = new Queue.from(parents2);

    var initialCombinator = _mergeInitialCombinators(queue1, queue2);
    if (initialCombinator == null) return null;
    var finalCombinator = _mergeFinalCombinators(queue1, queue2);
    if (finalCombinator == null) return null;

    // Make sure there's at most one `:root` in the output.
    var root1 = _hasRoot(queue1.first) ? queue1.removeFirst() : null;
    var root2 = _hasRoot(queue2.first) ? queue2.removeFirst() : null;
    if (root1 != null && root2 != null) {
      var root = root1.unify(root2);
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
    var lcs = longestCommonSubsequence(groups1, groups2, (group1, group2) {
      if (listEquals(group1, group2)) return group1;
      if (group1.first is! CompoundSelector ||
          group2.first is! CompoundSelector) {
        return null;
      }
      if (_isParentSuperselector(group1, group2)) return group2;
      if (_isParentSuperselector(group2, group1)) return group1;
      if (!_mustUnify(group1, group2)) return null;

      var unified = _unifyComplex(group1, group2);
      if (unified == null) return null;
      if (unified.members.length > 1) return null;
      return unified.members.first.members;
    });

    var choices = [[initialCombinator]];
    for (var group in lcs) {
      choices.add(_chunks(groups1, groups2,
          (sequence) => _isParentSuperselector(sequence.first, group)));
      choices.add(group);
      groups1.removeFirst();
      groups2.removeFirst();
    }
    choices.add(_chunks(groups1, groups2, (sequence) => sequence.isEmpty));
    choices.addAll(finalCombinator);

    return paths(choices.where((choice) => choice.isNotEmpty))
        .map((path) => path.expand((group) => group));
  }

  List<Combinator> _mergeInitialCombinators(
      Queue<ComplexSelectorComponent> components1,
      Queue<ComplexSelectorComponent> components2) {
    var combinators1 = <Combinator>[];
    while (components1.first is Combinator) {
      combinators1.add(components1.first as Combinator);
    }

    var combinators2 = <Combinator>[];
    while (components2.first is Combinator) {
      combinators2.add(components2.first as Combinator);
    }

    // If neither sequence of combinators is a subsequence of the other, they
    // cannot be merged successfully.
    var lcs = leastCommonSubsequence(combinators1, combinators2);
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
      var lcs = leastCommonSubsequence(combinators1, combinators2);
      if (listEquals(lcs, combinators1)) {
        result.addAll(combinators2.reversed);
      } else if (listEquals(lcs, combinators2)) {
        result.addAll(combinators1.reversed);
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
        if (compound1.isSuperselectorOf(compound2)) {
          result.addFirst([[compound2, Combinator.followingSibling]]);
        } else if (compound2.isSuperselectorOf(compound1)) {
          result.addFirst([[compound1, Combinator.followingSibling]]);
        } else {
          var choices = [
            [
              compound1, Combinator.followingSibling,
              compound2, Combinator.followingSibling
            ],
            [
              compound2, Combinator.followingSibling,
              compound1, Combinator.followingSibling
            ]
          ];

          var unified = _unifyCompound(compound1.members, compound2.members);
          if (unified != null) {
            choices.add([unified, Combinator.followingSibling]);
          }

          result.addFirst(choices);
        }
      } else if (
          (combinator1 == Combinator.followingSibling &&
           combinator2 == Combinator.nextSibling) ||
          (combinator1 == Combinator.nextSibling &&
           combinator2 == Combinator.followingSibling)) {
        var followingSiblingSelector =
            combinator1 == Combinator.followingSibling ? compound1 : compound2;
        var nextSiblingSelector =
            combinator1 == Combinator.followingSibling ? compound2 : compound1;

        if (followingSiblingSelector.isSuperselectorOf(nextSiblingSelector)) {
          result.addFirst([[nextSiblingSelector, Combinator.nextSibling]]);
        } else {
          var choices = [
            [
              followingSiblingSelector, Combinator.followingSibling,
              nextSiblingSelector, Combinator.nextSibling
            ]
          ];

          var unified = _unifyCompound(compound1.members, compound2.members);
          if (unified != null) choices.add([unified, Combinator.nextSibling]);
          result.addFirst(choices);
        }
      } else if (combinator1 == Combinator.child &&
          (combinator2 == Combinator.nextSibling ||
           combinator2 == Combinator.followingSibling)) {
        result.addFirst([[compound2, combinator2]]);
        components1..add(compound1)..add(Combinator.child);
      } else if (combinator2 == Combinator.child &&
          (combinator1 == Combinator.nextSibling ||
           combinator1 == Combinator.followingSibling)) {
        result.addFirst([[compound2, combinator2]]);
        components1..add(compound1)..add(Combinator.child);
      } else if (combinator1 == combinator2) {
        var unified = _unifyCompound(compound1.members, compound2.members);
        if (unified == null) return null;
        result.addFirst([[merged, combinator1]]);
      } else {
        return null;
      }

      return _mergeFinalCombinators(components1, components2, result);
    } else if (combinator1 != null) {
      if (combinator1 == Combinator.child &&
          components2.isNotEmpty &&
          components2.last.isSuperselectorOf(components1.last)) {
        components2.removeLast();
      }
      result.addFirst([[components1.removeLast(), combinator1]]);
      return _mergeFinalCombinators(components1, components2, result);
    } else {
      assert(combinator1 != null);
      if (combinator2 == Combinator.child &&
          components1.isNotEmpty &&
          components1.last.isSuperselectorOf(components2.last)) {
        components1.removeLast();
      }
      result.addFirst([[components2.removeLast(), combinator2]]);
      return _mergeFinalCombinators(components1, components2, result);
    }
  }

  List<List/*<T>*/> _chunks/*<T>*/(Queue<List/*<T>*/> queue1,
      Queue<List/*<T>*/> queue2, bool done(Queue<List/*<T>*/> queue)) {
    var chunk1 = /*<T>*/[];
    while (!done(queue1)) {
      chunk1.add(queue1.removeFirst());
    }

    var chunk2 = /*<T>*/[];
    while (!done(queue2)) {
      chunk2.add(queue2.removeFirst());
    }

    if (chunk1.isEmpty && chunk2.isEmpty) return [];
    if (chunk1.isEmpty) return [chunk2];
    if (chunk2.isEmpty) return [chunk1];
    return [chunk1.toList()..addAll(chunk2), chunk2.addAll(chunk1)];
  }

  Queue<List<ComplexSelectorComponent>> _groupSelectors(
      Iterable<ComplexSelectorComponent> selectors) {
    var groups = new Queue<List<ComplexSelectorComponent>>();
    var iterator = selectors.iterator;
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

  bool _isParentSuperselector(List<ComplexSelectorComponent> selectors1,
      List<ComplexSelectorComponent> selectors2) {
    // Try some simple heuristics to see if we can avoid allocations.
    if (selectors1.first is Combinator) return false;
    if (selectors2.first is Combinator) return false;
    if (selectors1.length > selectors2.length) return false;

    // TODO(nweiz): There's got to be a way to do this without a bunch of extra
    // allocations...
    var base = new CompoundSelector([new PlaceholderSelector('<temp>')]);
    return _isSuperselector(
        selectors1..toList().add(base), selectors2..toList().add(base));
  }

  bool _isParentSuperselector(List<ComplexSelectorComponent> selectors1,
      List<ComplexSelectorComponent> selectors2) {
    // Selectors with trailing operators are neither superselectors nor
    // subselectors.
    if (selectors1.last is Combinator) return false;
    if (selectors2.last is Combinator) return false;

    var i1 = 0;
    var i2 = 0;
    while (true) {
      var remaining1 = selectors1.length - i1;
      var remaining2 = selectors2.length - i2;
      if (remaining1 == 0 || remaining2 == 0) return false;

      // More complex selectors are never superselectors of less complex ones.
      if (remaining1 > remaining2) return false;

      // Selectors with leading operators are neither superselectors nor
      // subselectors.
      if (selectors1[i1] is Combinator) return false;
      if (selectors2[i2] is Combinator) return false;

      if (remaining1 == 1) {
        var selector = selectors1[i1] as CompoundSelector;
        return selector.isSuperselectorOfComplex(selectors2.sublist(i2));
      }

      // Find the first index where `selectors2.sublist(i2, afterSuperselector)`
      // is a subselector of `selectors1[i1]`. We stop before the superselector
      // would encompass all of [selectors2] because we know [selectors1] has
      // more than one element, and consuming all of [selectors2] wouldn't leave
      // anything for the rest of [selectors1] to match.
      var afterSuperselector = i2 + 1;
      for (; afterSuperselector <= selectors2.length; afterSuperselector++) {
        if (selectors2[afterSuperselector - 1] is Combinator) continue;

        if (selectors1[i1].isSuperselectorOfComplex(
            selectors2.sublist(i2, afterSuperselector))) {
          break;
        }
      }
      if (afterSuperselector == selectors2.length) return false;

      var combinator1 = selectors1[i1 + 1];
      var combinator2 = selectors1[afterSuperselector];
      if (combinator1 is Combinator) {
        if (combinator2 is! Combinator) return false;

        // `.foo ~ .bar` is a superselector of `.foo + .bar`, but otherwise the
        // combinators must match.
        if (combinator1 == Combinator.followingSibling) {
          if (combinator2 == Combinator.child) return false;
        } else if (combinator2 != combinator1) {
          return false;
        }

        // `.foo > .baz` is not a superselector of `.foo > .bar > .baz` or
        // `.foo > .bar .baz`, despite the fact that `.baz` is a superselector of
        // `.bar > .baz` and `.bar .baz`. Same goes for `+` and `~`.
        if (remaining1 == 3 && remaining2 > 3) return false;

        i1 += 2;
        i2 = afterSuperselector + 1;
      } else if (combinator2 is Combinator) {
        if (combinator2 != Combinator2.child) return false;
        i1++;
        i2 = afterSuperselector + 1;
      } else {
        i1++;
        i2 = afterSuperselector;
      }
    }
  }

  List<List<ComplexSelectorComponent>> _trim(
      List<List<List<ComplexSelectorComponent>>> weaves) {
    // Avoid truly horrific quadratic behavior.
    //
    // TODO(nweiz): I think there may be a way to get perfect trimming without
    // going quadratic by building some sort of trie-like data structure that
    // can be used to look up superselectors.
    if (path.length > 100) return weave.expand((selectors) => selectors);

    // This is n² on the sequences, but only comparing between separate
    // sequences should limit the quadratic behavior.
    var result = <List<ComplexSelectorComponent>>[];
    for (var i = 0; i < weaves.length; i++) {
      for (var selector1 in weaves[1]) {
        // The maximum specificity of the sources that caused [selector1] to be
        // generated. In order for [selector1] to be removed, there must be another
        // selector that's a superselector of it *and* that has specificity
        // greater or equal to this.
        var maxSpecificity =
            maxBy(_sources(selector1), (source) => source.maxSpecificity) ?? 0;

        // Look in [result] rather than [weaves] for selectors before [i]. This
        // ensures that we aren't comparing against a selector that's already
        // been trimmed, and thus that if there are two identical selectors only
        // one is trimmed.
        if (result.any((selector2) =>
            selector2.minSpecificity >= maxSpecificity &&
            _isSuperselector(selector2, selector1))) {
          return false;
        }

        if (weaves.skip(i + 1).any((selector2) =>
            selector2.minSpecificity >= maxSpecificity &&
            _isSuperselector(selector2, selector1))) {
          return false;
        }

        result.add(selector1);
      }
    }

    return result;
  }
}
