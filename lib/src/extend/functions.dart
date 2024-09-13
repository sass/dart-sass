// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// This library contains utility functions related to extending selectors.
///
/// These functions aren't private methods on [ExtensionStore] because they also
/// need to be accessible from elsewhere in the codebase. In addition, they
/// aren't instance methods on other objects because their APIs aren't a good
/// fit—usually because they deal with raw component lists rather than selector
/// classes, to reduce allocations.
library;

import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';

import '../ast/css/value.dart';
import '../ast/selector.dart';
import '../util/iterable.dart';
import '../util/span.dart';
import '../utils.dart';

/// Pseudo-selectors that can only meaningfully appear in the first component of
/// a complex selector.
final _rootishPseudoClasses = {'root', 'scope', 'host', 'host-context'};

/// Returns the contents of a [SelectorList] that matches only elements that are
/// matched by every complex selector in [complexes].
///
/// The [span] is used for the unified complex selectors.
///
/// If no such list can be produced, returns `null`.
List<ComplexSelector>? unifyComplex(
    List<ComplexSelector> complexes, FileSpan span) {
  if (complexes.length == 1) return complexes;

  CompoundSelector? unifiedBase;
  CssValue<Combinator>? leadingCombinator;
  CssValue<Combinator>? trailingCombinator;
  for (var complex in complexes) {
    if (complex.isUseless) return null;

    if (complex
        case ComplexSelector(
          components: [_],
          leadingCombinators: [var newLeadingCombinator]
        )) {
      if (leadingCombinator == null) {
        leadingCombinator = newLeadingCombinator;
      } else if (leadingCombinator != newLeadingCombinator) {
        return null;
      }
    }

    var base = complex.components.last;
    if (base
        case ComplexSelectorComponent(
          combinators: [var newTrailingCombinator]
        )) {
      if (trailingCombinator != null &&
          trailingCombinator != newTrailingCombinator) {
        return null;
      }
      trailingCombinator = newTrailingCombinator;
    }

    if (unifiedBase == null) {
      unifiedBase = base.selector;
    } else {
      unifiedBase = unifyCompound(unifiedBase, base.selector);
      if (unifiedBase == null) return null;
    }
  }

  var withoutBases = [
    for (var complex in complexes)
      if (complex.components.length > 1)
        ComplexSelector(complex.leadingCombinators,
            complex.components.exceptLast, complex.span,
            lineBreak: complex.lineBreak),
  ];

  var base = ComplexSelector(
      leadingCombinator == null ? const [] : [leadingCombinator],
      [
        ComplexSelectorComponent(unifiedBase!,
            trailingCombinator == null ? const [] : [trailingCombinator], span)
      ],
      span,
      lineBreak: complexes.any((complex) => complex.lineBreak));

  return weave(
      withoutBases.isEmpty
          ? [base]
          : [
              ...withoutBases.exceptLast,
              withoutBases.last.concatenate(base, span)
            ],
      span);
}

/// Returns a [CompoundSelector] that matches only elements that are matched by
/// both [compound1] and [compound2].
///
/// The [span] will be used for the new unified selector.
///
/// This function ensures that the relative order of pseudo-classes (`:`) and
/// pseudo-elements (`::`) within each input selector is preserved in the
/// resulting combined selector.
///
/// This function enforces a general rule that pseudo-classes (`:`) should come
/// before pseudo-elements (`::`), but it won't change their order if they were
/// originally interleaved within a single input selector. This prevents
/// unintended changes to the selector's meaning. For example, unifying
/// `::foo:bar` and `:baz` results in `:baz::foo:bar`. `:baz` is a pseudo-class,
/// so it is moved before the pseudo-class `::foo`. Meanwhile, `:bar` is not
/// moved before `::foo` because it appeared after `::foo` in the original
/// selector.
///
/// If no such selector can be produced, returns `null`.
CompoundSelector? unifyCompound(
    CompoundSelector compound1, CompoundSelector compound2) {
  // The compound selectors are split at pseudo-elements (::) to ensure that
  // pseudo-classes (:) aren't moved across pseudo-element boundaries.
  var compoundParts1 = compound1.components
      .splitAfter((simple) => simple is PseudoSelector && simple.isElement);
  var compoundParts2 = compound2.components
      .splitAfter((simple) => simple is PseudoSelector && simple.isElement);
  var result = <SimpleSelector>[];
  for (var [components1, components2]
      in IterableZip([compoundParts1, compoundParts2])) {
    var resultPart = [...components1];
    for (var simple in components2) {
      var unified = simple.unify(resultPart);
      if (unified == null) return null;
      resultPart = unified;
    }
    result.addAll(resultPart);
  }

  var minLength = min(compoundParts1.length, compoundParts2.length);
  result.addAll(compoundParts1.skip(minLength).flattened);
  result.addAll(compoundParts2.skip(minLength).flattened);

  return CompoundSelector(result, compound1.span);
}

/// Returns a [SimpleSelector] that matches only elements that are matched by
/// both [selector1] and [selector2], which must both be either
/// [UniversalSelector]s or [TypeSelector]s.
///
/// The [span] will be used for the new unified selector.
///
/// If no such selector can be produced, returns `null`.
SimpleSelector? unifyUniversalAndElement(
    SimpleSelector selector1, SimpleSelector selector2) {
  var (namespace1, name1) = _namespaceAndName(selector1, 'selector1');
  var (namespace2, name2) = _namespaceAndName(selector2, 'selector2');

  String? namespace;
  if (namespace1 == namespace2 || namespace2 == '*') {
    namespace = namespace1;
  } else if (namespace1 == '*') {
    namespace = namespace2;
  } else {
    return null;
  }

  String? name;
  if (name1 == name2 || name2 == null) {
    name = name1;
  } else if (name1 == null || name1 == '*') {
    name = name2;
  } else {
    return null;
  }

  return name == null
      ? UniversalSelector(selector1.span, namespace: namespace)
      : TypeSelector(QualifiedName(name, namespace: namespace), selector1.span);
}

/// Returns the namespace and name for [selector], which must be a
/// [UniversalSelector] or a [TypeSelector].
///
/// The [name] parameter is used for error reporting.
(String? namespace, String? name) _namespaceAndName(
        SimpleSelector selector, String name) =>
    switch (selector) {
      UniversalSelector(:var namespace) => (namespace, null),
      TypeSelector(name: QualifiedName(:var name, :var namespace)) => (
          namespace,
          name
        ),
      _ => throw ArgumentError.value(
          selector, name, 'must be a UniversalSelector or a TypeSelector')
    };

/// Expands "parenthesized selectors" in [complexes].
///
/// That is, if we have `.A .B {@extend .C}` and `.D .C {...}`, this
/// conceptually expands into `.D .C, .D (.A .B)`, and this function translates
/// `.D (.A .B)` into `.D .A .B, .A .D .B`. For thoroughness, `.A.D .B` would
/// also be required, but including merged selectors results in exponential
/// output for very little gain.
///
/// The selector `.D (.A .B)` is represented as the list `[.D, .A .B]`.
///
/// The [span] will be used for any new combined selectors.
///
/// If [forceLineBreak] is `true`, this will mark all returned complex selectors
/// as having line breaks.
List<ComplexSelector> weave(List<ComplexSelector> complexes, FileSpan span,
    {bool forceLineBreak = false}) {
  if (complexes case [var complex]) {
    if (!forceLineBreak || complex.lineBreak) return complexes;
    return [
      ComplexSelector(
          complex.leadingCombinators, complex.components, complex.span,
          lineBreak: true)
    ];
  }

  var prefixes = [complexes.first];
  for (var complex in complexes.skip(1)) {
    if (complex.components.length == 1) {
      for (var i = 0; i < prefixes.length; i++) {
        prefixes[i] = prefixes[i]
            .concatenate(complex, span, forceLineBreak: forceLineBreak);
      }
      continue;
    }

    prefixes = [
      for (var prefix in prefixes)
        for (var parentPrefix in _weaveParents(prefix, complex, span) ??
            const <ComplexSelector>[])
          parentPrefix.withAdditionalComponent(complex.components.last, span,
              forceLineBreak: forceLineBreak),
    ];
  }

  return prefixes;
}

/// Interweaves [prefix]'s components with [base]'s components _other than
/// the last_.
///
/// Returns all possible orderings of the selectors in the inputs (including
/// using unification) that maintain the relative ordering of the input. For
/// example, given `.foo .bar` and `.baz .bang div`, this would return `.foo
/// .bar .baz .bang div`, `.foo .bar.baz .bang div`, `.foo .baz .bar .bang div`,
/// `.foo .baz .bar.bang div`, `.foo .baz .bang .bar div`, and so on until `.baz
/// .bang .foo .bar div`.
///
/// Semantically, for selectors `P` and `C`, this returns all selectors `PC_i`
/// such that the union over all `i` of elements matched by `PC_i` is identical
/// to the intersection of all elements matched by `C` and all descendants of
/// elements matched by `P`. Some `PC_i` are elided to reduce the size of the
/// output.
///
/// The [span] will be used for any new combined selectors.
///
/// Returns `null` if this intersection is empty.
Iterable<ComplexSelector>? _weaveParents(
    ComplexSelector prefix, ComplexSelector base, FileSpan span) {
  var leadingCombinators = _mergeLeadingCombinators(
      prefix.leadingCombinators, base.leadingCombinators);
  if (leadingCombinators == null) return null;

  // Make queues of _only_ the parent selectors. The prefix only contains
  // parents, but the complex selector has a target that we don't want to weave
  // in.
  var queue1 = QueueList.from(prefix.components);
  var queue2 = QueueList.from(base.components.exceptLast);

  var trailingCombinators = _mergeTrailingCombinators(queue1, queue2, span);
  if (trailingCombinators == null) return null;

  // Make sure all selectors that are required to be at the root are unified
  // with one another.
  switch ((_firstIfRootish(queue1), _firstIfRootish(queue2))) {
    case (var rootish1?, var rootish2?):
      var rootish = unifyCompound(rootish1.selector, rootish2.selector);
      if (rootish == null) return null;
      queue1.addFirst(ComplexSelectorComponent(
          rootish, rootish1.combinators, rootish1.span));
      queue2.addFirst(ComplexSelectorComponent(
          rootish, rootish2.combinators, rootish1.span));

    case (var rootish?, null):
    case (null, var rootish?):
      // If there's only one rootish selector, it should only appear in the first
      // position of the resulting selector. We can ensure that happens by adding
      // it to the beginning of _both_ queues.
      queue1.addFirst(rootish);
      queue2.addFirst(rootish);
  }

  var groups1 = _groupSelectors(queue1);
  var groups2 = _groupSelectors(queue2);
  var lcs = longestCommonSubsequence<List<ComplexSelectorComponent>>(
      groups2, groups1, select: (group1, group2) {
    if (listEquals(group1, group2)) return group1;
    if (_complexIsParentSuperselector(group1, group2)) return group2;
    if (_complexIsParentSuperselector(group2, group1)) return group1;
    if (!_mustUnify(group1, group2)) return null;

    var unified = unifyComplex([
      ComplexSelector(const [], group1, span),
      ComplexSelector(const [], group2, span)
    ], span);
    return unified?.singleOrNull?.components;
  });

  var choices = <List<Iterable<ComplexSelectorComponent>>>[];
  for (var group in lcs) {
    choices.add([
      for (var chunk in _chunks<List<ComplexSelectorComponent>>(
          groups1,
          groups2,
          (sequence) => _complexIsParentSuperselector(sequence.first, group)))
        [for (var components in chunk) ...components]
    ]);
    choices.add([group]);
    groups1.removeFirst();
    groups2.removeFirst();
  }
  choices.add([
    for (var chunk in _chunks(groups1, groups2, (sequence) => sequence.isEmpty))
      [for (var components in chunk) ...components]
  ]);
  choices.addAll(trailingCombinators);

  return [
    for (var path in paths(choices.where((choice) => choice.isNotEmpty)))
      ComplexSelector(leadingCombinators,
          [for (var components in path) ...components], span,
          lineBreak: prefix.lineBreak || base.lineBreak)
  ];
}

/// If the first element of [queue] has a selector like `:root` that can only
/// appear in a complex selector's first component, removes and returns that
/// element.
ComplexSelectorComponent? _firstIfRootish(
    QueueList<ComplexSelectorComponent> queue) {
  if (queue case [var first, ...]) {
    for (var simple in first.selector.components) {
      if (simple case PseudoSelector(isClass: true, :var normalizedName)
          when _rootishPseudoClasses.contains(normalizedName)) {
        queue.removeFirst();
        return first;
      }
    }
  }

  return null;
}

/// Returns a leading combinator list that's compatible with both [combinators1]
/// and [combinators2].
///
/// Returns `null` if the combinator lists can't be unified.
List<CssValue<Combinator>>? _mergeLeadingCombinators(
        List<CssValue<Combinator>>? combinators1,
        List<CssValue<Combinator>>? combinators2) =>
    // Allow null arguments just to make calls to `Iterable.reduce()` easier.
    switch ((combinators1, combinators2)) {
      (null, _) || (_, null) => null,
      (List(length: > 1), _) || (_, List(length: > 1)) => null,
      ([], var combinators) || (var combinators, []) => combinators,
      _ => listEquals(combinators1, combinators2) ? combinators1 : null
    };

/// Extracts trailing [ComplexSelectorComponent]s with trailing combinators from
/// [components1] and [components2] and merges them together into a single list.
///
/// Each element in the returned list is a set of choices for a particular
/// position in a complex selector. Each choice is the contents of a complex
/// selector, which is to say a list of complex selector components. The union
/// of each path through these choices will match the full set of necessary
/// elements.
///
/// If there are no combinators to be merged, returns an empty list. If the
/// sequences can't be merged, returns `null`.
///
/// The [span] will be used for any new combined selectors.
List<List<List<ComplexSelectorComponent>>>? _mergeTrailingCombinators(
    QueueList<ComplexSelectorComponent> components1,
    QueueList<ComplexSelectorComponent> components2,
    FileSpan span,
    [QueueList<List<List<ComplexSelectorComponent>>>? result]) {
  result ??= QueueList();

  var combinators1 = switch (components1) {
    [..., var last] => last.combinators,
    _ => const <CssValue<Combinator>>[]
  };
  var combinators2 = switch (components2) {
    [..., var last] => last.combinators,
    _ => const <CssValue<Combinator>>[]
  };
  if (combinators1.isEmpty && combinators2.isEmpty) return result;
  if (combinators1.length > 1 || combinators2.length > 1) return null;

  // This code looks complicated, but it's actually just a bunch of special
  // cases for interactions between different combinators.
  switch ((
    combinators1.firstOrNull?.value,
    combinators2.firstOrNull?.value,
    // Include the component lists in the pattern match so we can easily
    // generalize cases across different orderings of the two combinators.
    components1,
    components2
  )) {
    case (Combinator.followingSibling, Combinator.followingSibling, _, _):
      var component1 = components1.removeLast();
      var component2 = components2.removeLast();
      if (component1.selector.isSuperselector(component2.selector)) {
        result.addFirst([
          [component2]
        ]);
      } else if (component2.selector.isSuperselector(component1.selector)) {
        result.addFirst([
          [component1]
        ]);
      } else {
        var choices = [
          [component1, component2],
          [component2, component1]
        ];

        if (unifyCompound(component1.selector, component2.selector)
            case var unified?) {
          choices.add([
            ComplexSelectorComponent(unified, [combinators1.first], span)
          ]);
        }

        result.addFirst(choices);
      }

    case (
            Combinator.followingSibling,
            Combinator.nextSibling,
            var followingComponents,
            var nextComponents
          ) ||
          (
            Combinator.nextSibling,
            Combinator.followingSibling,
            var nextComponents,
            var followingComponents
          ):
      var next = nextComponents.removeLast();
      var following = followingComponents.removeLast();
      if (following.selector.isSuperselector(next.selector)) {
        result.addFirst([
          [next]
        ]);
      } else {
        result.addFirst([
          [following, next],
          if (unifyCompound(following.selector, next.selector)
              case var unified?)
            [ComplexSelectorComponent(unified, next.combinators, span)]
        ]);
      }

    case (
        Combinator.child,
        Combinator.nextSibling || Combinator.followingSibling,
        _,
        var siblingComponents
      ):
    case (
        Combinator.nextSibling || Combinator.followingSibling,
        Combinator.child,
        var siblingComponents,
        _
      ):
      result.addFirst([
        [siblingComponents.removeLast()]
      ]);

    case (var combinator1?, var combinator2?, _, _)
        when combinator1 == combinator2:
      var unified = unifyCompound(
          components1.removeLast().selector, components2.removeLast().selector);
      if (unified == null) return null;
      result.addFirst([
        [
          ComplexSelectorComponent(unified, [combinators1.first], span)
        ]
      ]);

    case (
        var combinator?,
        null,
        var combinatorComponents,
        var descendantComponents
      ):
    case (
        null,
        var combinator?,
        var descendantComponents,
        var combinatorComponents
      ):
      if (combinator == Combinator.child &&
          (descendantComponents.lastOrNull?.selector
                  .isSuperselector(combinatorComponents.last.selector) ??
              false)) {
        descendantComponents.removeLast();
      }
      result.addFirst([
        [combinatorComponents.removeLast()]
      ]);

    case _:
      return null;
  }

  return _mergeTrailingCombinators(components1, components2, span, result);
}

/// Returns whether [complex1] and [complex2] need to be unified to produce a
/// valid combined selector.
///
/// This is necessary when both selectors contain the same unique simple
/// selector, such as an ID.
bool _mustUnify(List<ComplexSelectorComponent> complex1,
    List<ComplexSelectorComponent> complex2) {
  var uniqueSelectors = {
    for (var component in complex1)
      ...component.selector.components.where(_isUnique)
  };
  if (uniqueSelectors.isEmpty) return false;

  return complex2.any((component) => component.selector.components
      .any((simple) => _isUnique(simple) && uniqueSelectors.contains(simple)));
}

/// Returns whether a [CompoundSelector] may contain only one simple selector of
/// the same type as [simple].
bool _isUnique(SimpleSelector simple) =>
    simple is IDSelector || (simple is PseudoSelector && simple.isElement);

/// Returns all orderings of initial subsequences of [queue1] and [queue2].
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

  return switch ((chunk1, chunk2)) {
    ([], []) => [],
    ([], var chunk) || (var chunk, []) => [chunk],
    _ => [
        [...chunk1, ...chunk2],
        [...chunk2, ...chunk1]
      ]
  };
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
        .expand((option) => paths.map((path) => [...path, option]))
        .toList());

/// Returns [complex], grouped into the longest possible sub-lists such that
/// [ComplexSelectorComponent]s without combinators only appear at the end of
/// sub-lists.
///
/// For example, `(A B > C D + E ~ G)` is grouped into
/// `[(A) (B > C) (D + E ~ G)]`.
QueueList<List<ComplexSelectorComponent>> _groupSelectors(
    Iterable<ComplexSelectorComponent> complex) {
  var groups = QueueList<List<ComplexSelectorComponent>>();
  var group = <ComplexSelectorComponent>[];
  for (var component in complex) {
    group.add(component);
    if (component.combinators.isEmpty) {
      groups.add(group);
      group = [];
    }
  }

  if (group.isNotEmpty) groups.add(group);
  return groups;
}

/// Returns whether [list1] is a superselector of [list2].
///
/// That is, whether [list1] matches every element that [list2] matches, as well
/// as possibly additional elements.
bool listIsSuperselector(
        List<ComplexSelector> list1, List<ComplexSelector> list2) =>
    list2.every((complex1) =>
        list1.any((complex2) => complex2.isSuperselector(complex1)));

/// Like [complexIsSuperselector], but compares [complex1] and [complex2] as
/// though they shared an implicit base [SimpleSelector].
///
/// For example, `B` is not normally a superselector of `B A`, since it doesn't
/// match elements that match `A`. However, it *is* a parent superselector,
/// since `B X` is a superselector of `B A X`.
bool _complexIsParentSuperselector(List<ComplexSelectorComponent> complex1,
    List<ComplexSelectorComponent> complex2) {
  if (complex1.length > complex2.length) return false;

  // TODO(nweiz): There's got to be a way to do this without a bunch of extra
  // allocations...
  var base = ComplexSelectorComponent(
      CompoundSelector([PlaceholderSelector('<temp>', bogusSpan)], bogusSpan),
      const [],
      bogusSpan);
  return complexIsSuperselector([...complex1, base], [...complex2, base]);
}

/// Returns whether [complex1] is a superselector of [complex2].
///
/// That is, whether [complex1] matches every element that [complex2] matches, as well
/// as possibly additional elements.
bool complexIsSuperselector(List<ComplexSelectorComponent> complex1,
    List<ComplexSelectorComponent> complex2) {
  // Selectors with trailing operators are neither superselectors nor
  // subselectors.
  if (complex1.last.combinators.isNotEmpty) return false;
  if (complex2.last.combinators.isNotEmpty) return false;

  var i1 = 0;
  var i2 = 0;
  CssValue<Combinator>? previousCombinator;
  while (true) {
    var remaining1 = complex1.length - i1;
    var remaining2 = complex2.length - i2;
    if (remaining1 == 0 || remaining2 == 0) return false;

    // More complex selectors are never superselectors of less complex ones.
    if (remaining1 > remaining2) return false;

    var component1 = complex1[i1];
    if (component1.combinators.length > 1) return false;
    if (remaining1 == 1) {
      if (complex2.any((parent) => parent.combinators.length > 1)) {
        return false;
      } else {
        return compoundIsSuperselector(
            component1.selector, complex2.last.selector,
            parents: component1.selector.hasComplicatedSuperselectorSemantics
                ? complex2.sublist(i2, complex2.length - 1)
                : null);
      }
    }

    // Find the first index [endOfSubselector] in [complex2] such that
    // `complex2.sublist(i2, endOfSubselector + 1)` is a subselector of
    // [component1.selector].
    var endOfSubselector = i2;
    while (true) {
      var component2 = complex2[endOfSubselector];
      if (component2.combinators.length > 1) return false;
      if (compoundIsSuperselector(component1.selector, component2.selector,
          parents: component1.selector.hasComplicatedSuperselectorSemantics
              ? complex2.sublist(i2, endOfSubselector)
              : null)) {
        break;
      }

      endOfSubselector++;
      if (endOfSubselector == complex2.length - 1) {
        // Stop before the superselector would encompass all of [complex2]
        // because we know [complex1] has more than one element, and consuming
        // all of [complex2] wouldn't leave anything for the rest of [complex1]
        // to match.
        return false;
      }
    }

    if (!_compatibleWithPreviousCombinator(
        previousCombinator, complex2.take(endOfSubselector).skip(i2))) {
      return false;
    }

    var component2 = complex2[endOfSubselector];
    var combinator1 = component1.combinators.firstOrNull;
    var combinator2 = component2.combinators.firstOrNull;
    if (!_isSupercombinator(combinator1, combinator2)) {
      return false;
    }

    i1++;
    i2 = endOfSubselector + 1;
    previousCombinator = combinator1;

    if (complex1.length - i1 == 1) {
      if (combinator1?.value == Combinator.followingSibling) {
        // The selector `.foo ~ .bar` is only a superselector of selectors that
        // *exclusively* contain subcombinators of `~`.
        if (!complex2.take(complex2.length - 1).skip(i2).every((component) =>
            _isSupercombinator(
                combinator1, component.combinators.firstOrNull))) {
          return false;
        }
      } else if (combinator1 != null) {
        // `.foo > .bar` and `.foo + bar` aren't superselectors of any selectors
        // with more than one combinator.
        if (complex2.length - i2 > 1) return false;
      }
    }
  }
}

/// Returns whether [parents] are valid intersitial components between one
/// complex superselector and another, given that the earlier complex
/// superselector had the combinator [previous].
bool _compatibleWithPreviousCombinator(CssValue<Combinator>? previous,
    Iterable<ComplexSelectorComponent> parents) {
  if (parents.isEmpty) return true;
  if (previous == null) return true;

  // The child and next sibling combinators require that the *immediate*
  // following component be a superslector.
  if (previous.value != Combinator.followingSibling) return false;

  // The following sibling combinator does allow intermediate components, but
  // only if they're all siblings.
  return parents.every((component) =>
      component.combinators.firstOrNull?.value == Combinator.followingSibling ||
      component.combinators.firstOrNull?.value == Combinator.nextSibling);
}

/// Returns whether [combinator1] is a supercombinator of [combinator2].
///
/// That is, whether `X combinator1 Y` is a superselector of `X combinator2 Y`.
bool _isSupercombinator(
        CssValue<Combinator>? combinator1, CssValue<Combinator>? combinator2) =>
    combinator1 == combinator2 ||
    (combinator1 == null && combinator2?.value == Combinator.child) ||
    (combinator1?.value == Combinator.followingSibling &&
        combinator2?.value == Combinator.nextSibling);

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
    {Iterable<ComplexSelectorComponent>? parents}) {
  if (!compound1.hasComplicatedSuperselectorSemantics &&
      !compound2.hasComplicatedSuperselectorSemantics) {
    if (compound1.components.length > compound2.components.length) return false;
    return compound1.components
        .every((simple1) => compound2.components.any(simple1.isSuperselector));
  }

  // Pseudo elements effectively change the target of a compound selector rather
  // than narrowing the set of elements to which it applies like other
  // selectors. As such, if either selector has a pseudo element, they both must
  // have the _same_ pseudo element.
  //
  // In addition, order matters when pseudo-elements are involved. The selectors
  // before them must
  switch ((
    _findPseudoElementIndexed(compound1),
    _findPseudoElementIndexed(compound2)
  )) {
    case ((var pseudo1, var index1), (var pseudo2, var index2)):
      return pseudo1.isSuperselector(pseudo2) &&
          _compoundComponentsIsSuperselector(compound1.components.take(index1),
              compound2.components.take(index2), parents: parents) &&
          _compoundComponentsIsSuperselector(
              compound1.components.skip(index1 + 1),
              compound2.components.skip(index2 + 1),
              parents: parents);

    case (_?, _) || (_, _?):
      return false;
  }

  // Every selector in [compound1.components] must have a matching selector in
  // [compound2.components].
  for (var simple1 in compound1.components) {
    if (simple1 case PseudoSelector(selector: _?)) {
      if (!_selectorPseudoIsSuperselector(simple1, compound2,
          parents: parents)) {
        return false;
      }
    } else if (!compound2.components.any(simple1.isSuperselector)) {
      return false;
    }
  }

  return true;
}

/// If [compound] contains a pseudo-element, returns it and its index in
/// [compound.components].
(PseudoSelector, int)? _findPseudoElementIndexed(CompoundSelector compound) {
  for (var i = 0; i < compound.components.length; i++) {
    var simple = compound.components[i];
    if (simple case PseudoSelector(isElement: true)) return (simple, i);
  }
  return null;
}

/// Like [compoundIsSuperselector] but operates on the underlying lists of
/// simple selectors.
///
/// The [compound1] and [compound2] are expected to have efficient
/// [Iterable.length] fields.
bool _compoundComponentsIsSuperselector(
    Iterable<SimpleSelector> compound1, Iterable<SimpleSelector> compound2,
    {Iterable<ComplexSelectorComponent>? parents}) {
  if (compound1.isEmpty) return true;
  if (compound2.isEmpty) {
    compound2 = [UniversalSelector(bogusSpan, namespace: '*')];
  }
  return compoundIsSuperselector(CompoundSelector(compound1, bogusSpan),
      CompoundSelector(compound2, bogusSpan),
      parents: parents);
}

/// Returns whether [pseudo1] is a superselector of [compound2].
///
/// That is, whether [pseudo1] matches every element that [compound2] matches,
/// as well as possibly additional elements.
///
/// This assumes that [pseudo1]'s `selector` argument is not `null`.
///
/// If [parents] is passed, it represents the parents of [compound2]. This is
/// relevant for pseudo selectors with selector arguments, where we may need to
/// know if the parent selectors in the selector argument match [parents].
bool _selectorPseudoIsSuperselector(
    PseudoSelector pseudo1, CompoundSelector compound2,
    {Iterable<ComplexSelectorComponent>? parents}) {
  var selector1 = pseudo1.selector;
  if (selector1 == null) {
    throw ArgumentError("Selector $pseudo1 must have a selector argument.");
  }

  switch (pseudo1.normalizedName) {
    case 'is':
    case 'matches':
    case 'any':
    case 'where':
      var selectors = _selectorPseudoArgs(compound2, pseudo1.name);
      return selectors
              .any((selector2) => selector1.isSuperselector(selector2)) ||
          selector1.components.any((complex1) =>
              complex1.leadingCombinators.isEmpty &&
              complexIsSuperselector(complex1.components, [
                ...?parents,
                ComplexSelectorComponent(compound2, const [], compound2.span)
              ]));

    case 'has':
    case 'host':
    case 'host-context':
      return _selectorPseudoArgs(compound2, pseudo1.name)
          .any((selector2) => selector1.isSuperselector(selector2));

    case 'slotted':
      return _selectorPseudoArgs(compound2, pseudo1.name, isClass: false)
          .any((selector2) => selector1.isSuperselector(selector2));

    case 'not':
      return selector1.components.every((complex) {
        if (complex.isBogus) return false;

        return compound2.components.any((simple2) => switch (simple2) {
              TypeSelector() => complex.components.last.selector.components.any(
                  (simple1) => simple1 is TypeSelector && simple1 != simple2),
              IDSelector() => complex.components.last.selector.components.any(
                  (simple1) => simple1 is IDSelector && simple1 != simple2),
              PseudoSelector(selector: var selector2?)
                  when simple2.name == pseudo1.name =>
                listIsSuperselector(selector2.components, [complex]),
              _ => false
            });
      });

    case 'current':
      return _selectorPseudoArgs(compound2, pseudo1.name)
          .any((selector2) => selector1 == selector2);

    case 'nth-child':
    case 'nth-last-child':
      return compound2.components.any((pseudo2) {
        if (pseudo2 is! PseudoSelector) return false;
        if (pseudo2.name != pseudo1.name) return false;
        if (pseudo2.argument != pseudo1.argument) return false;
        var selector2 = pseudo2.selector;
        if (selector2 == null) return false;
        return selector1.isSuperselector(selector2);
      });

    default:
      throw "unreachable";
  }
}

/// Returns all the selector arguments of pseudo selectors in [compound] with
/// the given [name].
Iterable<SelectorList> _selectorPseudoArgs(
        CompoundSelector compound, String name, {bool isClass = true}) =>
    compound.components
        .whereType<PseudoSelector>()
        .where((pseudo) => pseudo.isClass == isClass && pseudo.name == name)
        .map((pseudo) => pseudo.selector)
        .nonNulls;
