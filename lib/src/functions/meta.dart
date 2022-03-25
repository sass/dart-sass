// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../callable.dart';
import '../value.dart';

/// Feature names supported by Dart sass.
final _features = {
  "global-variable-shadowing",
  "extend-selector-pseudoclass",
  "units-level-3",
  "at-error",
  "custom-property"
};

/// The global definitions of Sass introspection functions.
final global = UnmodifiableListView([
  // This is only a partial list of meta functions. The rest are defined in the
  // evaluator, because they need access to context that's only available at
  // runtime.
  _function("feature-exists", r"$feature", (arguments) {
    var feature = arguments[0].assertString("feature");
    return SassBoolean(_features.contains(feature.text));
  }),

  _function("inspect", r"$value",
      (arguments) => SassString(arguments.first.toString(), quotes: false)),

  _function("type-of", r"$value", (arguments) {
    var value = arguments[0];
    if (value is SassArgumentList) {
      return SassString("arglist", quotes: false);
    }
    if (value is SassBoolean) return SassString("bool", quotes: false);
    if (value is SassColor) return SassString("color", quotes: false);
    if (value is SassList) return SassString("list", quotes: false);
    if (value is SassMap) return SassString("map", quotes: false);
    if (value == sassNull) return SassString("null", quotes: false);
    if (value is SassNumber) return SassString("number", quotes: false);
    if (value is SassFunction) return SassString("function", quotes: false);
    if (value is SassCalculation) {
      return SassString("calculation", quotes: false);
    }
    assert(value is SassString);
    return SassString("string", quotes: false);
  }),

  _function("keywords", r"$args", (arguments) {
    var argumentList = arguments[0];
    if (argumentList is SassArgumentList) {
      return SassMap({
        for (var entry in argumentList.keywords.entries)
          SassString(entry.key, quotes: false): entry.value
      });
    } else {
      throw "\$args: $argumentList is not an argument list.";
    }
  })
]);

/// The definitions of Sass introspection functions that are only available from
/// the `sass:meta` module, not as global functions.
final local = UnmodifiableListView([
  _function("calc-name", r"$calc", (arguments) {
    var calculation = arguments[0].assertCalculation("calc");
    return SassString(calculation.name);
  }),
  _function("calc-args", r"$calc", (arguments) {
    var calculation = arguments[0].assertCalculation("calc");
    return SassList(calculation.arguments.map((argument) {
      if (argument is Value) return argument;
      return SassString(argument.toString(), quotes: false);
    }), ListSeparator.comma);
  })
]);

/// Like [new BuiltInCallable.function], but always sets the URL to `sass:meta`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:meta");
