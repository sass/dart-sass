// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../callable.dart';
import '../module/built_in.dart';
import '../value.dart';

/// The global definitions of Sass map functions.
final global = UnmodifiableListView([
  _get.withName("map-get"),
  _merge.withName("map-merge"),
  _remove.withName("map-remove"),
  _keys.withName("map-keys"),
  _values.withName("map-values"),
  _hasKey.withName("map-has-key")
]);

/// The Sass map module.
final module = BuiltInModule("map",
    functions: [_get, _merge, _remove, _keys, _values, _hasKey]);

final _get = _function("get", r"$map, $key", (arguments) {
  var map = arguments[0].assertMap("map");
  var key = arguments[1];
  return map.contents[key] ?? sassNull;
});

final _merge = _function("merge", r"$map1, $map2", (arguments) {
  var map1 = arguments[0].assertMap("map1");
  var map2 = arguments[1].assertMap("map2");
  return SassMap({...map1.contents, ...map2.contents});
});

final _remove = BuiltInCallable.overloadedFunction("remove", {
  // Because the signature below has an explicit `$key` argument, it doesn't
  // allow zero keys to be passed. We want to allow that case, so we add an
  // explicit overload for it.
  r"$map": (arguments) => arguments[0].assertMap("map"),

  // The first argument has special handling so that the $key parameter can be
  // passed by name.
  r"$map, $key, $keys...": (arguments) {
    var map = arguments[0].assertMap("map");
    var keys = [arguments[1], ...arguments[2].asList];
    var mutableMap = Map.of(map.contents);
    for (var key in keys) {
      mutableMap.remove(key);
    }
    return SassMap(mutableMap);
  }
});

final _keys = _function(
    "keys",
    r"$map",
    (arguments) => SassList(
        arguments[0].assertMap("map").contents.keys, ListSeparator.comma));

final _values = _function(
    "values",
    r"$map",
    (arguments) => SassList(
        arguments[0].assertMap("map").contents.values, ListSeparator.comma));

final _hasKey = _function("has-key", r"$map, $key, $keys...", (arguments) {
  var map = arguments[0].assertMap("map");
  var keys = [arguments[1], ...arguments[2].asList];
  for (var key in keys.sublist(0, keys.length - 1)) {
    var value = map.contents[key];
    if (value is SassMap) {
      map = value;
    } else {
      return sassFalse;
    }
  }
  return SassBoolean(map.contents.containsKey(keys.last));
});

/// Like [new BuiltInCallable.function], but always sets the URL to `sass:map`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:map");
