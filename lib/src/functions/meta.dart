// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../ast/sass/statement/mixin_rule.dart';
import '../callable.dart';
import '../deprecation.dart';
import '../evaluation_context.dart';
import '../util/map.dart';
import '../value.dart';

/// Feature names supported by Dart sass.
final _features = {
  "global-variable-shadowing",
  "extend-selector-pseudoclass",
  "units-level-3",
  "at-error",
  "custom-property"
};

/// Sass introspection functions that exist as both global functions and in the
/// `sass:meta` module that do not require access to context that's only
/// available at runtime.
///
/// Additional functions are defined in the evaluator.
final _shared = UnmodifiableListView([
  // This is only a partial list of meta functions. The rest are defined in the
  // evaluator, because they need access to context that's only available at
  // runtime.
  _function("feature-exists", r"$feature", (arguments) {
    warnForDeprecation(
        "The feature-exists() function is deprecated.\n\n"
        "More info: https://sass-lang.com/d/feature-exists",
        Deprecation.featureExists);
    var feature = arguments[0].assertString("feature");
    return SassBoolean(_features.contains(feature.text));
  }),
  _function("inspect", r"$value",
      (arguments) => SassString(arguments.first.toString(), quotes: false)),
  _function(
      "type-of",
      r"$value",
      (arguments) => SassString(
          switch (arguments[0]) {
            SassArgumentList() => "arglist",
            SassBoolean() => "bool",
            SassColor() => "color",
            SassList() => "list",
            SassMap() => "map",
            sassNull => "null",
            SassNumber() => "number",
            SassFunction() => "function",
            SassMixin() => "mixin",
            SassCalculation() => "calculation",
            SassString() => "string",
            _ => throw "[BUG] Unknown value type ${arguments[0]}"
          },
          quotes: false)),
  _function("keywords", r"$args", (arguments) {
    if (arguments[0] case SassArgumentList(:var keywords)) {
      return SassMap({
        for (var (key, value) in keywords.pairs)
          SassString(key, quotes: false): value
      });
    } else {
      throw "\$args: ${arguments[0]} is not an argument list.";
    }
  })
]);

/// The global definitions of Sass introspection functions.
final global = UnmodifiableListView(
    [for (var function in _shared) function.withDeprecationWarning('meta')]);

/// The versions of Sass introspection functions defined in the `sass:meta`
/// module.
final moduleFunctions = UnmodifiableListView([
  ..._shared,
  _function("calc-name", r"$calc", (arguments) {
    var calculation = arguments[0].assertCalculation("calc");
    return SassString(calculation.name);
  }),
  _function("calc-args", r"$calc", (arguments) {
    var calculation = arguments[0].assertCalculation("calc");
    return SassList(
        calculation.arguments.map((argument) => argument is Value
            ? argument
            : SassString(argument.toString(), quotes: false)),
        ListSeparator.comma);
  }),
  _function("accepts-content", r"$mixin", (arguments) {
    var mixin = arguments[0].assertMixin("mixin");
    return SassBoolean(switch (mixin.callable) {
      AsyncBuiltInCallable(acceptsContent: var acceptsContent) ||
      BuiltInCallable(acceptsContent: var acceptsContent) =>
        acceptsContent,
      UserDefinedCallable(declaration: MixinRule(hasContent: var hasContent)) =>
        hasContent,
      _ => throw UnsupportedError("Unknown callable type $mixin.")
    });
  })
]);

/// Like [BuiltInCallable.function], but always sets the URL to `sass:meta`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:meta");
