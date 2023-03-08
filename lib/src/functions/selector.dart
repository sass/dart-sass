// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../ast/selector.dart';
import '../callable.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../extend/extension_store.dart';
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
final module = BuiltInModule("selector", functions: <Callable>[
  _isSuperselector,
  _simpleSelectors,
  _parse,
  _nest,
  _append,
  _extend,
  _replace,
  _unify
]);

final _nest = _function("nest", r"$selectors...", (arguments) {
  var selectors = arguments[0].asList;
  if (selectors.isEmpty) {
    throw SassScriptException(
        "\$selectors: At least one selector must be passed.");
  }

  var first = true;
  return selectors
      .map((selector) {
        var result = selector.assertSelector(allowParent: !first);
        first = false;
        return result;
      })
      .reduce((parent, child) => child.resolveParentSelectors(parent))
      .asSassList;
});

final _append = _function("append", r"$selectors...", (arguments) {
  var selectors = arguments[0].asList;
  if (selectors.isEmpty) {
    throw SassScriptException(
        "\$selectors: At least one selector must be passed.");
  }

  var span = EvaluationContext.current.currentCallableSpan;
  return selectors
      .map((selector) => selector.assertSelector())
      .reduce((parent, child) {
    return SelectorList(child.components.map((complex) {
      if (complex.leadingCombinators.isNotEmpty) {
        throw SassScriptException("Can't append $complex to $parent.");
      }

      var component = complex.components.first;
      var newCompound = _prependParent(component.selector);
      if (newCompound == null) {
        throw SassScriptException("Can't append $complex to $parent.");
      }

      return ComplexSelector(const [], [
        ComplexSelectorComponent(newCompound, component.combinators, span),
        ...complex.components.skip(1)
      ], span);
    }), span)
        .resolveParentSelectors(parent);
  }).asSassList;
});

final _extend =
    _function("extend", r"$selector, $extendee, $extender", (arguments) {
  var selector = arguments[0].assertSelector(name: "selector")
    ..assertNotBogus(name: "selector");
  var target = arguments[1].assertSelector(name: "extendee")
    ..assertNotBogus(name: "extendee");
  var source = arguments[2].assertSelector(name: "extender")
    ..assertNotBogus(name: "extender");

  return ExtensionStore.extend(selector, source, target,
          EvaluationContext.current.currentCallableSpan)
      .asSassList;
});

final _replace =
    _function("replace", r"$selector, $original, $replacement", (arguments) {
  var selector = arguments[0].assertSelector(name: "selector")
    ..assertNotBogus(name: "selector");
  var target = arguments[1].assertSelector(name: "original")
    ..assertNotBogus(name: "original");
  var source = arguments[2].assertSelector(name: "replacement")
    ..assertNotBogus(name: "replacement");

  return ExtensionStore.replace(selector, source, target,
          EvaluationContext.current.currentCallableSpan)
      .asSassList;
});

final _unify = _function("unify", r"$selector1, $selector2", (arguments) {
  var selector1 = arguments[0].assertSelector(name: "selector1")
    ..assertNotBogus(name: "selector1");
  var selector2 = arguments[1].assertSelector(name: "selector2")
    ..assertNotBogus(name: "selector2");

  var result = selector1.unify(selector2);
  return result == null ? sassNull : result.asSassList;
});

final _isSuperselector =
    _function("is-superselector", r"$super, $sub", (arguments) {
  var selector1 = arguments[0].assertSelector(name: "super")
    ..assertNotBogus(name: "super");
  var selector2 = arguments[1].assertSelector(name: "sub")
    ..assertNotBogus(name: "sub");

  return SassBoolean(selector1.isSuperselector(selector2));
});

final _simpleSelectors =
    _function("simple-selectors", r"$selector", (arguments) {
  var selector = arguments[0].assertCompoundSelector(name: "selector");

  return SassList(
      selector.components
          .map((simple) => SassString(simple.toString(), quotes: false)),
      ListSeparator.comma);
});

final _parse = _function("parse", r"$selector",
    (arguments) => arguments[0].assertSelector(name: "selector").asSassList);

/// Adds a [ParentSelector] to the beginning of [compound], or returns `null` if
/// that wouldn't produce a valid selector.
CompoundSelector? _prependParent(CompoundSelector compound) {
  var first = compound.components.first;
  if (first is UniversalSelector) return null;

  var span = EvaluationContext.current.currentCallableSpan;
  if (first is TypeSelector) {
    if (first.name.namespace != null) return null;
    return CompoundSelector([
      ParentSelector(span, suffix: first.name.name),
      ...compound.components.skip(1)
    ], span);
  } else {
    return CompoundSelector(
        [ParentSelector(span), ...compound.components], span);
  }
}

/// Like [BuiltInCallable.function], but always sets the URL to
/// `sass:selector`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:selector");
