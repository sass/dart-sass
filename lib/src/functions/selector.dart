// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../ast/selector.dart';
import '../callable.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../extend/extension_store.dart';
import '../module/built_in.dart';
import '../value.dart';

/// The global definitions of Sass selector functions.
@internal
final global = UnmodifiableListView([
  _isSuperselector.withDeprecationWarning('selector'),
  _simpleSelectors.withDeprecationWarning('selector'),
  _parse.withDeprecationWarning('selector').withName("selector-parse"),
  _nest.withDeprecationWarning('selector').withName("selector-nest"),
  _append.withDeprecationWarning('selector').withName("selector-append"),
  _extend.withDeprecationWarning('selector').withName("selector-extend"),
  _replace.withDeprecationWarning('selector').withName("selector-replace"),
  _unify.withDeprecationWarning('selector').withName("selector-unify"),
]);

/// The Sass selector module.
@internal
final module = BuiltInModule(
  "selector",
  functions: <Callable>[
    _isSuperselector,
    _simpleSelectors,
    _parse,
    _nest,
    _append,
    _extend,
    _replace,
    _unify,
  ],
);

final _nest = _function("nest", r"$selectors...", (arguments) {
  var selectors = arguments[0].asList;
  if (selectors.isEmpty) {
    throw SassScriptException(
      "\$selectors: At least one selector must be passed.",
    );
  }

  var first = true;
  return selectors
      .map((selector) {
        var result = selector.assertSelector(
          allowParent: !first,
          allowLeadingCombinator: true,
          allowTrailingCombinator: true,
        );
        first = false;
        return result;
      })
      .reduce((parent, child) => child.nestWithin(parent))
      .asSassList;
});

final _append = _function("append", r"$selectors...", (arguments) {
  var selectors = arguments[0].asList;
  if (selectors.isEmpty) {
    throw SassScriptException(
      "\$selectors: At least one selector must be passed.",
    );
  }

  var span = EvaluationContext.current.currentCallableSpan;
  SelectorList? parent;
  for (var i = 0; i < selectors.length; i++) {
    var child = selectors[i].assertSelector(
      allowLeadingCombinator: true,
      allowTrailingCombinator: true,
    );
    if (parent == null) {
      parent = child;
      continue;
    }

    parent = SelectorList(
      child.components.map((complex) {
        if (complex.leadingCombinator != null || complex.components.isEmpty) {
          throw SassScriptException("Can't append $complex to $parent.");
        }

        var [component, ...rest] = complex.components;
        var newCompound = _prependParent(component.selector);
        if (newCompound == null) {
          throw SassScriptException("Can't append $complex to $parent.");
        }

        return ComplexSelector([
          ComplexSelectorComponent(
            newCompound,
            span,
            combinator: component.combinator,
          ),
          ...rest,
        ], span);
      }),
      span,
    ).nestWithin(parent);
  }

  return parent!.asSassList;
});

final _extend = _function("extend", r"$selector, $extendee, $extender", (
  arguments,
) {
  var selector = arguments[0]
      .assertSelector(name: "selector", allowLeadingCombinator: true);
  var target = arguments[1].assertSelector(name: "extendee");
  var source = arguments[2].assertSelector(name: "extender");

  return ExtensionStore.extend(
    selector,
    source,
    target,
    EvaluationContext.current.currentCallableSpan,
  ).asSassList;
});

final _replace = _function("replace", r"$selector, $original, $replacement", (
  arguments,
) {
  var selector = arguments[0]
      .assertSelector(name: "selector", allowLeadingCombinator: true);
  var target = arguments[1].assertSelector(name: "original");
  var source = arguments[2].assertSelector(name: "replacement");

  return ExtensionStore.replace(
    selector,
    source,
    target,
    EvaluationContext.current.currentCallableSpan,
  ).asSassList;
});

final _unify = _function("unify", r"$selector1, $selector2", (arguments) {
  var selector1 = arguments[0]
      .assertSelector(name: "selector1", allowLeadingCombinator: true);
  var selector2 = arguments[1]
      .assertSelector(name: "selector2", allowLeadingCombinator: true);

  return selector1.unify(selector2)?.asSassList ?? sassNull;
});

final _isSuperselector = _function("is-superselector", r"$super, $sub", (
  arguments,
) {
  var selector1 = arguments[0].assertSelector(name: "super");
  var selector2 = arguments[1].assertSelector(name: "sub");

  return SassBoolean(selector1.isSuperselector(selector2));
});

final _simpleSelectors = _function("simple-selectors", r"$selector", (
  arguments,
) {
  var selector = arguments[0].assertCompoundSelector(name: "selector");

  return SassList(
    selector.components.map(
      (simple) => SassString(simple.toString(), quotes: false),
    ),
    ListSeparator.comma,
  );
});

final _parse = _function(
  "parse",
  r"$selector",
  (arguments) => arguments[0]
      .assertSelector(
        name: "selector",
        allowLeadingCombinator: true,
        allowTrailingCombinator: true,
      )
      .asSassList,
);

/// Adds a [ParentSelector] to the beginning of [compound], or returns `null` if
/// that wouldn't produce a valid selector.
CompoundSelector? _prependParent(CompoundSelector compound) {
  var span = EvaluationContext.current.currentCallableSpan;
  return switch (compound.components) {
    [UniversalSelector(), ...] => null,
    [TypeSelector type, ...] when type.name.namespace != null => null,
    [TypeSelector type, ...var rest] => CompoundSelector([
        ParentSelector(span, suffix: type.name.name),
        ...rest,
      ], span),
    var components => CompoundSelector([
        ParentSelector(span),
        ...components,
      ], span),
  };
}

/// Like [BuiltInCallable.function], but always sets the URL to
/// `sass:selector`.
BuiltInCallable _function(
  String name,
  String arguments,
  Value callback(List<Value> arguments),
) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:selector");
