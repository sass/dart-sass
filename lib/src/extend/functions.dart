// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/selector.dart';

final _subselectorPseudos =
    new Set.from(['matches', 'any', 'nth-child', 'nth-last-child']);

SimpleSelector unifyUniversalAndElement(SimpleSelector selector1,
    SimpleSelector selector2) {
  String namespace1;
  String name1;
  if (selector1 is UniversalSelector) {
    namespace1 = selector1.namespace;
  } else if (selector1 is TypeSelector) {
    namespace1 = selector1.name.namespace;
    name1 = selector1.name.name;
  } else {
    throw new ArgumentError.value(
        selector1,
        'selector1',
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
    throw new ArgumentError.value(
        selector2,
        'selector2',
        'must be a UniversalSelector or a TypeSelector');
  }

  String namespace;
  if (namespace1 == namespace2 || namespace2 == null || namespace2 == '*') {
    namespace = namespace1;
  } else if (namespace1 == null || namespace1 == '*') {
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
      : new TypeSelector(
                new NamespacedIdentifier(name, namespace: namespace));
}

bool listIsSuperslector(List<ComplexSelector> list1,
        List<ComplexSelector> list2) =>
    list2.every((complex1) =>
        list1.any((complex2) => complex2.isSuperselector(complex1)));

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
      complex1..toList().add(base), complex2..toList().add(base));
}

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

    if (remaining1 == 1) {
      var selector = complex1[i1] as CompoundSelector;
      return compoundIsSuperselector(selector, complex2[i2],
          parents: complex2.skip(i2 + 1));
    }

    // Find the first index where `complex2.sublist(i2, afterSuperselector)` is
    // a subselector of `complex1[i1]`. We stop before the superselector would
    // encompass all of [complex2] because we know [complex1] has more than one
    // element, and consuming all of [complex2] wouldn't leave anything for the
    // rest of [complex1] to match.
    var afterSuperselector = i2 + 1;
    for (; afterSuperselector <= complex2.length; afterSuperselector++) {
      if (complex2[afterSuperselector - 1] is Combinator) continue;

      if (compoundIsSuperselector(
          complex1[i1],
          complex2[i2],
          parents: complex2.take(afterSuperselector - 1).skip(i2 + 1))) {
        break;
      }
    }
    if (afterSuperselector == complex2.length) return false;

    var combinator1 = complex1[i1 + 1];
    var combinator2 = complex1[afterSuperselector];
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

bool compoundIsSuperselector(CompoundSelector compound1,
    CompoundSelector compound2, {Iterable<ComplexSelectorComponent> parents}) {
  // Every selector in [compound1.components] must have a matching selector in
  // [compound2.components].
  for (var simple1 in compound1.components) {
    if (simple1 is PseudoSelector && simple1.selector != null) {
      if (!_selectorPseudoIsSuperselector(
          simple1, compound2, parents: parents)) {
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
        simple2.type == PseudoType.element &&
        !_simpleIsSuperselectorOfCompound(simple2, compound1)) {
      return false;
    }
  }

  return true;
}

bool _simpleIsSuperselectorOfCompound(SimpleSelector simple,
    CompoundSelector compound) {
  return compound.components.any((theirSimple) {
    if (simple == theirSimple) return true;

    // Some selector pseudoclasses can match normal selectors.
    if (theirSimple is PseudoSelector && theirSimple.selector != null &&
        _subselectorPseudos.contains(theirSimple.normalizedName)) {
      return theirSimple.selector.components.any((complex) {
        if (complex.components.length != 1) return false;
        var compound = complex.components.single as CompoundSelector;
        return compound.components.contains(simple);
      });
    } else {
      return false;
    }
  });
}

bool _selectorPseudoIsSuperselector(PseudoSelector pseudo1,
    CompoundSelector compound2, {Iterable<ComplexSelectorComponent> parents}) {
  switch (pseudo1.normalizedName) {
    case 'matches':
    case 'any':
      var pseudos = _selectorPseudosNamed(compound2, pseudo1.normalizedName);
      return pseudos.any((pseudo2) {
        return pseudo1.selector.isSuperselector(pseudo2.selector);
      }) || pseudo1.selector.components.any((complex1) {
        var complex2 = (parents?.toList() ?? [])..add(compound2);
        return complexIsSuperselector(complex1.components, complex2);
      });

    case 'has':
    case 'host':
    case 'host-context':
      return _selectorPseudosNamed(compound2, pseudo1.normalizedName)
          .any((pseudo2) => pseudo1.selector.isSuperselector(pseudo2.selector));

    case 'not':
      return pseudo1.selector.components.every((complex) {
        return compound2.components.every((simple2) {
          if (simple2 is TypeSelector) {
            var compound1 = complex.components.last;
            return compound1 is CompoundSelector &&
                compound1.components.any((simple1) =>
                    simple1 is TypeSelector && simple1 != simple2);
          } else if (simple2 is IDSelector) {
            var compound1 = complex.components.last;
            return compound1 is CompoundSelector &&
                compound1.components.any((simple1) =>
                    simple1 is IDSelector && simple1 != simple2);
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

Iterable<PseudoSelector> _selectorPseudosNamed(CompoundSelector compound,
    String name) =>
        compound.components.where((simple) =>
            simple is PseudoSelector &&
            simple.type == PseudoType.klass &&
            simple.selector != null &&
            simple.name == name);
