// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// This library contains utility functions related to extending selectors.
///
/// These functions aren't private methods on [Extender] because they also need
/// to be accessible from elsewhere in the codebase. In addition, they aren't
/// instance methods on other objects because their APIs aren't a good
/// fit—usually because they deal with raw component lists rather than selector
/// classes, to reduce allocations.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../ast/selector.dart';
import '../utils.dart';

/// Names of pseudo selectors that take selectors as arguments, and that are
/// subselectors of their arguments.
///
/// For example, `.foo` is a superselector of `:matches(.foo)`.
final _subselectorPseudos =
    new Set.of(['matches', 'any', 'nth-child', 'nth-last-child']);

/// Returns the contents of a [SelectorList] that matches only elements that are
/// matched by both [complex1] and [complex2].
///
/// If no such list can be produced, returns `null`.
List<List<ComplexSelectorComponent>> unifyComplex(
    List<List<ComplexSelectorComponent>> complexes) {
  assert(complexes.isNotEmpty);

  if (complexes.length == 1) return complexes;

  List<SimpleSelector> unifiedBase;
  for (var complex in complexes) {
    var base = complex.last;
    if (base is CompoundSelector) {
      if (unifiedBase == null) {
        unifiedBase = base.components;
      } else {
        for (var simple in base.components) {
          unifiedBase = simple.unify(unifiedBase);
          if (unifiedBase == null) return null;
        }
      }
    } else {
      return null;
    }
  }

  var complexesWithoutBases = complexes
      .map((complex) => complex.sublist(0, complex.length - 1))
      .toList();
  complexesWithoutBases.last.add(new CompoundSelector(unifiedBase));
  return weave(complexesWithoutBases);
}

/// Returns a [CompoundSelector] that matches only elements that are matched by
/// both [compound1] and [compound2].
///
/// If no such selector can be produced, returns `null`.
CompoundSelector unifyCompound(
    List<SimpleSelector> compound1, List<SimpleSelector> compound2) {
  var result = compound2;
  for (var simple in compound1) {
    result = simple.unify(result);
    if (result == null) return null;
  }

  return new CompoundSelector(result);
}

/// Returns a [SimpleSelector] that matches only elements that are matched by
/// both [selector1] and [selector2], which must both be either
/// [UniversalSelector]s or [TypeSelector]s.
///
/// If no such selector can be produced, returns `null`.
SimpleSelector unifyUniversalAndElement(
    SimpleSelector selector1, SimpleSelector selector2) {
  String namespace1;
  String name1;
  if (selector1 is UniversalSelector) {
    namespace1 = selector1.namespace;
  } else if (selector1 is TypeSelector) {
    namespace1 = selector1.name.namespace;
    name1 = selector1.name.name;
  } else {
    throw new ArgumentError.value(selector1, 'selector1',
        'must be a UniversalSelector or a TypeSelector');
  }

  String namespace2;
  String name2;
  if (selector2 is UniversalSelector) {
    namespace2 = selector2.namespace;
  } else if (selector2 is TypeSelector) {
    namespace2 = selector2.name.namespace;
    name2 = selector2.name.name;
  } else {
    throw new ArgumentError.value(selector2, 'selector2',
        'must be a UniversalSelector or a TypeSelector');
  }

  String namespace;
  if (namespace1 == namespace2 || namespace2 == '*') {
    namespace = namespace1;
  } else if (namespace1 == '*') {
    namespace = namespace2;
  } else {
    return null;
  }

  String name;
  if (name1 == name2 || name2 == null) {
    name = name1;
  } else if (name1 == null || name1 == '*') {
    name = name2;
  } else {
    return null;
  }

  return name == null
      ? new UniversalSelector(namespace: namespace)
      : new TypeSelector(new QualifiedName(name, namespace: namespace));
}

/// Expands "parenthesized selectors" in [complexes].
///
/// That is, if we have `.A .B {@extend .C}` and `.D .C {...}`, this
/// conceptually expands into `.D .C, .D (.A .B)`, and this function translates
/// `.D (.A .B)` into `.D .A .B, .A .D .B`. For thoroughness, `.A.D .B` would
/// also be required, but including merged selectors results in exponential
/// output for very little gain.
///
/// The selector `.D (.A .B)` is represented as the list `[[.D], [.A, .B]]`.
List<List<ComplexSelectorComponent>> weave(
    List<List<ComplexSelectorComponent>> complexes) {
  var prefixes = [complexes.first.toList()];

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

/// Interweaves [parents1] and [parents2] as parents of the same target selector.
///
/// Returns all possible orderings of the selectors in the inputs (including
/// using unification) that maintain the relative ordering of the input. For
/// example, given `.foo .bar` and `.baz .bang`, this would return `.foo .bar
/// .baz .bang`, `.foo .bar.baz .bang`, `.foo .baz .bar .bang`, `.foo .baz
/// .bar.bang`, `.foo .baz .bang .bar`, and so on until `.baz .bang .foo .bar`.
///
/// Semantically, for selectors A and B, this returns all selectors `AB_i`
/// such that the union over all i of elements matched by `AB_i X` is
/// identical to the intersection of all elements matched by `A X` and all
/// elements matched by `B X`. Some `AB_i` are elided to reduce the size of
/// the output.
Iterable<List<ComplexSelectorComponent>> _weaveParents(
    List<ComplexSelectorComponent> parents1,
    List<ComplexSelectorComponent> parents2) {
  var queue1 = new Queue.of(parents1);
  var queue2 = new Queue.of(parents2);

  var initialCombinators = _mergeInitialCombinators(queue1, queue2);
  if (initialCombinators == null) return null;
  var finalCombinators = _mergeFinalCombinators(queue1, queue2);
  if (finalCombinators == null) return null;

  // Make sure there's at most one `:root` in the output.
  var root1 = _firstIfRoot(queue1);
  var root2 = _firstIfRoot(queue2);
  if (root1 != null && root2 != null) {
    var root = unifyCompound(root1.components, root2.components);
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
  var lcs = longestCommonSubsequence<List<ComplexSelectorComponent>>(
      groups2, groups1, select: (group1, group2) {
    if (listEquals(group1, group2)) return group1;
    if (group1.first is! CompoundSelector ||
        group2.first is! CompoundSelector) {
      return null;
    }
    if (complexIsParentSuperselector(group1, group2)) return group2;
    if (complexIsParentSuperselector(group2, group1)) return group1;
    if (!_mustUnify(group1, group2)) return null;

    var unified = unifyComplex([group1, group2]);
    if (unified == null) return null;
    if (unified.length > 1) return null;
    return unified.first;
  });

  var choices = [
    <Iterable<ComplexSelectorComponent>>[initialCombinators]
  ];
  for (var group in lcs) {
    choices.add(_chunks<List<ComplexSelectorComponent>>(groups1, groups2,
            (sequence) => complexIsParentSuperselector(sequence.first, group))
        .map((chunk) => chunk.expand((group) => group))
        .toList());
    choices.add([group]);
    groups1.removeFirst();
    groups2.removeFirst();
  }
  choices.add(_chunks(groups1, groups2, (sequence) => sequence.isEmpty)
      .map((chunk) => chunk.expand((group) => group))
      .toList());
  choices.addAll(finalCombinators);

  return paths(choices.where((choice) => choice.isNotEmpty))
      .map((path) => path.expand((group) => group).toList());
}

/// If the first element of [queue] has a `::root` selector, removes and returns
/// that element.
CompoundSelector _firstIfRoot(Queue<ComplexSelectorComponent> queue) {
  if (queue.isEmpty) return null;
  var first = queue.first;
  if (first is CompoundSelector) {
    if (!_hasRoot(first)) return null;

    queue.removeFirst();
    return first;
  } else {
    return null;
  }
}

/// Extracts leading [Combinator]s from [components1] and [components2] and
/// merges them together into a single list of combinators.
///
/// If there are no combinators to be merged, returns an empty list. If the
/// combinators can't be merged, returns `null`.
List<Combinator> _mergeInitialCombinators(
    Queue<ComplexSelectorComponent> components1,
    Queue<ComplexSelectorComponent> components2) {
  var combinators1 = <Combinator>[];
  while (components1.isNotEmpty && components1.first is Combinator) {
    combinators1.add(components1.removeFirst() as Combinator);
  }

  var combinators2 = <Combinator>[];
  while (components2.isNotEmpty && components2.first is Combinator) {
    combinators2.add(components2.removeFirst() as Combinator);
  }

  // If neither sequence of combinators is a subsequence of the other, they
  // cannot be merged successfully.
  var lcs = longestCommonSubsequence(combinators1, combinators2);
  if (listEquals(lcs, combinators1)) return combinators2;
  if (listEquals(lcs, combinators2)) return combinators1;
  return null;
}

/// Extracts trailing [Combinator]s, and the selectors to which they apply, from
/// [components1] and [components2] and merges them together into a single list.
///
/// If there are no combinators to be merged, returns an empty list. If the
/// sequences can't be merged, returns `null`.
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
  while (components1.isNotEmpty && components1.last is Combinator) {
    combinators1.add(components1.removeLast() as Combinator);
  }

  var combinators2 = <Combinator>[];
  while (components2.isNotEmpty && components2.last is Combinator) {
    combinators2.add(components2.removeLast() as Combinator);
  }

  if (combinators1.length > 1 || combinators2.length > 1) {
    // If there are multiple combinators, something hacky's going on. If one
    // is a supersequence of the other, use that, otherwise give up.
    var lcs = longestCommonSubsequence(combinators1, combinators2);
    if (listEquals(lcs, combinators1)) {
      result.addFirst([new List.of(combinators2.reversed)]);
    } else if (listEquals(lcs, combinators2)) {
      result.addFirst([new List.of(combinators1.reversed)]);
    } else {
      return null;
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

        var unified = unifyCompound(compound1.components, compound2.components);
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

        var unified = unifyCompound(compound1.components, compound2.components);
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
        [compound1, combinator1]
      ]);
      components2..add(compound2)..add(Combinator.child);
    } else if (combinator1 == combinator2) {
      var unified = unifyCompound(compound1.components, compound2.components);
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
            .isSuperselector(components1.last as CompoundSelector)) {
      components2.removeLast();
    }
    result.addFirst([
      [components1.removeLast(), combinator1]
    ]);
    return _mergeFinalCombinators(components1, components2, result);
  } else {
    if (combinator2 == Combinator.child &&
        components1.isNotEmpty &&
        (components1.last as CompoundSelector)
            .isSuperselector(components2.last as CompoundSelector)) {
      components1.removeLast();
    }
    result.addFirst([
      [components2.removeLast(), combinator2]
    ]);
    return _mergeFinalCombinators(components1, components2, result);
  }
}

/// Returns whether [complex1] and [complex2] need to be unified to produce a
/// valid combined selector.
///
/// This is necessary when both selectors contain the same unique simple
/// selector, such as an ID.
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

/// Returns whether a [CompoundSelector] may contain only one simple selector of
/// the same type as [simple].
bool _isUnique(SimpleSelector simple) =>
    simple is IDSelector || (simple is PseudoSelector && simple.isElement);

/// Returns all orderings of initial subseqeuences of [queue1] and [queue2].
///
/// The [done] callback is used to determine the extent of the initial
/// subsequences. It's called with each queue until it returns `true`.
///
/// This destructively removes the initial subsequences of [queue1] and
/// [queue2].
///
/// For example, given `(A B C | D E)` and `(1 2 | 3 4 5)` (with `|` denoting
/// the boundary of the initial subsequence), this would return `[(A B C 1 2),
/// (1 2 A B C)]`. The queues would then contain `(D E)` and `(3 4 5)`.
List<List<T>> _chunks<T>(
    Queue<T> queue1, Queue<T> queue2, bool done(Queue<T> queue)) {
  var chunk1 = <T>[];
  while (!done(queue1)) {
    chunk1.add(queue1.removeFirst());
  }

  var chunk2 = <T>[];
  while (!done(queue2)) {
    chunk2.add(queue2.removeFirst());
  }

  if (chunk1.isEmpty && chunk2.isEmpty) return [];
  if (chunk1.isEmpty) return [chunk2];
  if (chunk2.isEmpty) return [chunk1];
  return [chunk1.toList()..addAll(chunk2), chunk2..addAll(chunk1)];
}

/// Returns a list of all possible paths through the given lists.
///
/// For example, given `[[1, 2], [3, 4], [5]]`, this returns:
///
/// ```
/// [[1, 3, 5],
///  [2, 3, 5],
///  [1, 4, 5],
///  [2, 4, 5]]
/// ```
List<List<T>> paths<T>(Iterable<List<T>> choices) => choices.fold(
    [[]],
    (paths, choice) => choice
        .expand((option) => paths.map((path) => path.toList()..add(option)))
        .toList());

/// Returns [complex], grouped into sub-lists such that no sub-list contains two
/// adjacent [ComplexSelector]s.
///
/// For example, `(A B > C D + E ~ > G)` is grouped into
/// `[(A) (B > C) (D + E ~ > G)]`.
QueueList<List<ComplexSelectorComponent>> _groupSelectors(
    Iterable<ComplexSelectorComponent> complex) {
  var groups = new QueueList<List<ComplexSelectorComponent>>();
  var iterator = complex.iterator..moveNext();
  while (iterator.current != null) {
    var group = <ComplexSelectorComponent>[];
    do {
      group.add(iterator.current);
    } while (iterator.moveNext() &&
        (iterator.current is Combinator || group.last is Combinator));
    groups.add(group);
  }
  return groups;
}

/// Returns whether or not [compound] contains a `::root` selector.
bool _hasRoot(CompoundSelector compound) => compound.components.any((simple) =>
    simple is PseudoSelector &&
    simple.isClass &&
    simple.normalizedName == 'root');

/// Returns whether [list1] is a superselector of [list2].
///
/// That is, whether [list1] matches every element that [list2] matches, as well
/// as possibly additional elements.
bool listIsSuperslector(
        List<ComplexSelector> list1, List<ComplexSelector> list2) =>
    list2.every((complex1) =>
        list1.any((complex2) => complex2.isSuperselector(complex1)));

/// Like [complexIsSuperselector], but compares [complex1] and [complex2] as
/// though they shared an implicit base [SimpleSelector].
///
/// For example, `B` is not normally a superselector of `B A`, since it doesn't
/// match elements that match `A`. However, it *is* a parent superselector,
/// since `B X` is a superselector of `B A X`.
bool complexIsParentSuperselector(List<ComplexSelectorComponent> complex1,
    List<ComplexSelectorComponent> complex2) {
  // Try some simple heuristics to see if we can avoid allocations.
  if (complex1.first is Combinator) return false;
  if (complex2.first is Combinator) return false;
  if (complex1.length > complex2.length) return false;

  // TODO(nweiz): There's got to be a way to do this without a bunch of extra
  // allocations...
  var base = new CompoundSelector([new PlaceholderSelector('<temp>')]);
  return complexIsSuperselector(
      complex1.toList()..add(base), complex2.toList()..add(base));
}

/// Returns whether [complex1] is a superselector of [complex2].
///
/// That is, whether [complex1] matches every element that [complex2] matches, as well
/// as possibly additional elements.
bool complexIsSuperselector(List<ComplexSelectorComponent> complex1,
    List<ComplexSelectorComponent> complex2) {
  // Selectors with trailing operators are neither superselectors nor
  // subselectors.
  if (complex1.last is Combinator) return false;
  if (complex2.last is Combinator) return false;

  var i1 = 0;
  var i2 = 0;
  while (true) {
    var remaining1 = complex1.length - i1;
    var remaining2 = complex2.length - i2;
    if (remaining1 == 0 || remaining2 == 0) return false;

    // More complex selectors are never superselectors of less complex ones.
    if (remaining1 > remaining2) return false;

    // Selectors with leading operators are neither superselectors nor
    // subselectors.
    if (complex1[i1] is Combinator) return false;
    if (complex2[i2] is Combinator) return false;
    var compound1 = complex1[i1] as CompoundSelector;

    if (remaining1 == 1) {
      return compoundIsSuperselector(
          compound1, complex2.last as CompoundSelector,
          parents: complex2.skip(i2 + 1));
    }

    // Find the first index where `complex2.sublist(i2, afterSuperselector)` is
    // a subselector of [compound1]. We stop before the superselector would
    // encompass all of [complex2] because we know [complex1] has more than one
    // element, and consuming all of [complex2] wouldn't leave anything for the
    // rest of [complex1] to match.
    var afterSuperselector = i2 + 1;
    for (; afterSuperselector < complex2.length; afterSuperselector++) {
      var compound2 = complex2[afterSuperselector - 1];
      if (compound2 is CompoundSelector) {
        if (compoundIsSuperselector(compound1, compound2,
            parents: complex2.take(afterSuperselector - 1).skip(i2 + 1))) {
          break;
        }
      }
    }
    if (afterSuperselector == complex2.length) return false;

    var combinator1 = complex1[i1 + 1];
    var combinator2 = complex2[afterSuperselector];
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
      if (combinator2 != Combinator.child) return false;
      i1++;
      i2 = afterSuperselector + 1;
    } else {
      i1++;
      i2 = afterSuperselector;
    }
  }
}

/// Returns whether [compound1] is a superselector of [compound2].
///
/// That is, whether [compound1] matches every element that [compound2] matches, as well
/// as possibly additional elements.
///
/// If [parents] is passed, it represents the parents of [compound2]. This is
/// relevant for pseudo selectors with selector arguments, where we may need to
/// know if the parent selectors in the selector argument match [parents].
bool compoundIsSuperselector(
    CompoundSelector compound1, CompoundSelector compound2,
    {Iterable<ComplexSelectorComponent> parents}) {
  // Every selector in [compound1.components] must have a matching selector in
  // [compound2.components].
  for (var simple1 in compound1.components) {
    if (simple1 is PseudoSelector && simple1.selector != null) {
      if (!_selectorPseudoIsSuperselector(simple1, compound2,
          parents: parents)) {
        return false;
      }
    } else if (!_simpleIsSuperselectorOfCompound(simple1, compound2)) {
      return false;
    }
  }

  // [compound1] can't be a superselector of a selector with pseudo-elements
  // that [compound2] doesn't share.
  for (var simple2 in compound2.components) {
    if (simple2 is PseudoSelector &&
        simple2.isElement &&
        !_simpleIsSuperselectorOfCompound(simple2, compound1)) {
      return false;
    }
  }

  return true;
}

/// Returns whether [simple] is a superselector of [compound].
///
/// That is, whether [simple] matches every element that [compound] matches, as
/// well as possibly additional elements.
bool _simpleIsSuperselectorOfCompound(
    SimpleSelector simple, CompoundSelector compound) {
  return compound.components.any((theirSimple) {
    if (simple == theirSimple) return true;

    // Some selector pseudoclasses can match normal selectors.
    if (theirSimple is PseudoSelector &&
        theirSimple.selector != null &&
        _subselectorPseudos.contains(theirSimple.normalizedName)) {
      return theirSimple.selector.components.every((complex) {
        if (complex.components.length != 1) return false;
        var compound = complex.components.single as CompoundSelector;
        return compound.components.contains(simple);
      });
    } else {
      return false;
    }
  });
}

/// Returns whether [pseudo1] is a superselector of [compound2].
///
/// That is, whether [pseudo1] matches every element that [compound2] matches, as well
/// as possibly additional elements.
///
/// This assumes that [pseudo1]'s `selector` argument is not `null`.
///
/// If [parents] is passed, it represents the parents of [compound2]. This is
/// relevant for pseudo selectors with selector arguments, where we may need to
/// know if the parent selectors in the selector argument match [parents].
bool _selectorPseudoIsSuperselector(
    PseudoSelector pseudo1, CompoundSelector compound2,
    {Iterable<ComplexSelectorComponent> parents}) {
  switch (pseudo1.normalizedName) {
    case 'matches':
    case 'any':
      var pseudos = _selectorPseudosNamed(compound2, pseudo1.name);
      return pseudos.any((pseudo2) {
            return pseudo1.selector.isSuperselector(pseudo2.selector);
          }) ||
          pseudo1.selector.components.any((complex1) {
            var complex2 = (parents?.toList() ?? <ComplexSelectorComponent>[])
              ..add(compound2);
            return complexIsSuperselector(complex1.components, complex2);
          });

    case 'has':
    case 'host':
    case 'host-context':
    case 'slotted':
      return _selectorPseudosNamed(compound2, pseudo1.name)
          .any((pseudo2) => pseudo1.selector.isSuperselector(pseudo2.selector));

    case 'not':
      return pseudo1.selector.components.every((complex) {
        return compound2.components.any((simple2) {
          if (simple2 is TypeSelector) {
            var compound1 = complex.components.last;
            return compound1 is CompoundSelector &&
                compound1.components.any(
                    (simple1) => simple1 is TypeSelector && simple1 != simple2);
          } else if (simple2 is IDSelector) {
            var compound1 = complex.components.last;
            return compound1 is CompoundSelector &&
                compound1.components.any(
                    (simple1) => simple1 is IDSelector && simple1 != simple2);
          } else if (simple2 is PseudoSelector &&
              simple2.name == pseudo1.name &&
              simple2.selector != null) {
            return listIsSuperslector(simple2.selector.components, [complex]);
          } else {
            return false;
          }
        });
      });

    case 'current':
      return _selectorPseudosNamed(compound2, 'current')
          .any((pseudo2) => pseudo1.selector == pseudo2.selector);

    case 'nth-child':
    case 'nth-last-child':
      return compound2.components.any((pseudo2) =>
          pseudo2 is PseudoSelector &&
          pseudo2.name == pseudo1.name &&
          pseudo2.argument == pseudo1.argument &&
          pseudo1.selector.isSuperselector(pseudo2.selector));

    default:
      throw "unreachable";
  }
}

/// Returns all pseudo selectors in [compound] that have a selector argument,
/// and that have the given [name].
Iterable<PseudoSelector> _selectorPseudosNamed(
        CompoundSelector compound, String name) =>
    // TODO(nweiz): Use whereType() when we only have to support Dart 2 runtime
    // semantics.
    compound.components
        .where((pseudo) =>
            pseudo is PseudoSelector &&
            pseudo.isClass &&
            pseudo.selector != null &&
            pseudo.name == name)
        .cast();
