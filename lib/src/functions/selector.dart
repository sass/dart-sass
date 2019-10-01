// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../ast/selector.dart';
import '../callable.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../module/built_in.dart';
import '../value.dart';

/// The global definitions of Sass selector functions.
final global = UnmodifiableListView([
  _isSuperselector,
  _simpleSelectors,
  _parse.withName("selector-parse"),
  _nest.withName("selector-nest"),
  _append.withName("selector-append"),
  _extend.withName("selector-extend"),
  _replace.withName("selector-replace"),
  _unify.withName("selector-unify")
]);

/// The Sass selector module.
final module = BuiltInModule("selector", functions: [
  _isSuperselector,
  _simpleSelectors,
  _parse,
  _nest,
  _append,
  _extend,
  _replace,
  _unify
]);

final _nest = BuiltInCallable("nest", r"$selectors...", (arguments) {
  var selectors = arguments[0].asList;
  if (selectors.isEmpty) {
    throw SassScriptException(
        "\$selectors: At least one selector must be passed.");
  }

  return selectors
      .map((selector) => selector.assertSelector(allowParent: true))
      .reduce((parent, child) => child.resolveParentSelectors(parent))
      .asSassList;
});

final _append = BuiltInCallable("append", r"$selectors...", (arguments) {
  var selectors = arguments[0].asList;
  if (selectors.isEmpty) {
    throw SassScriptException(
        "\$selectors: At least one selector must be passed.");
  }

  return selectors
      .map((selector) => selector.assertSelector())
      .reduce((parent, child) {
    return SelectorList(child.components.map((complex) {
      var compound = complex.components.first;
      if (compound is CompoundSelector) {
        var newCompound = _prependParent(compound);
        if (newCompound == null) {
          throw SassScriptException("Can't append $complex to $parent.");
        }

        return ComplexSelector([newCompound, ...complex.components.skip(1)]);
      } else {
        throw SassScriptException("Can't append $complex to $parent.");
      }
    })).resolveParentSelectors(parent);
  }).asSassList;
});

final _extend =
    BuiltInCallable("extend", r"$selector, $extendee, $extender", (arguments) {
  var selector = arguments[0].assertSelector(name: "selector");
  var target = arguments[1].assertSelector(name: "extendee");
  var source = arguments[2].assertSelector(name: "extender");

  return Extender.extend(selector, source, target).asSassList;
});

final _replace = BuiltInCallable(
    "replace", r"$selector, $original, $replacement", (arguments) {
  var selector = arguments[0].assertSelector(name: "selector");
  var target = arguments[1].assertSelector(name: "original");
  var source = arguments[2].assertSelector(name: "replacement");

  return Extender.replace(selector, source, target).asSassList;
});

final _unify = BuiltInCallable("unify", r"$selector1, $selector2", (arguments) {
  var selector1 = arguments[0].assertSelector(name: "selector1");
  var selector2 = arguments[1].assertSelector(name: "selector2");

  var result = selector1.unify(selector2);
  return result == null ? sassNull : result.asSassList;
});

final _isSuperselector =
    BuiltInCallable("is-superselector", r"$super, $sub", (arguments) {
  var selector1 = arguments[0].assertSelector(name: "super");
  var selector2 = arguments[1].assertSelector(name: "sub");

  return SassBoolean(selector1.isSuperselector(selector2));
});

final _simpleSelectors =
    BuiltInCallable("simple-selectors", r"$selector", (arguments) {
  var selector = arguments[0].assertCompoundSelector(name: "selector");

  return SassList(
      selector.components
          .map((simple) => SassString(simple.toString(), quotes: false)),
      ListSeparator.comma);
});

final _parse = BuiltInCallable("parse", r"$selector",
    (arguments) => arguments[0].assertSelector(name: "selector").asSassList);

/// Adds a [ParentSelector] to the beginning of [compound], or returns `null` if
/// that wouldn't produce a valid selector.
CompoundSelector _prependParent(CompoundSelector compound) {
  var first = compound.components.first;
  if (first is UniversalSelector) return null;
  if (first is TypeSelector) {
    if (first.name.namespace != null) return null;
    return CompoundSelector([
      ParentSelector(suffix: first.name.name),
      ...compound.components.skip(1)
    ]);
  } else {
    return CompoundSelector([ParentSelector(), ...compound.components]);
  }
}
