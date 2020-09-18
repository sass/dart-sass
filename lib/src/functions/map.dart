// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../callable.dart';
import '../exception.dart';
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
final module = BuiltInModule("map", functions: [
  _get, _set, _merge, _remove, _keys, _values, _hasKey, _deepMerge //
]);

final _get = _function("get", r"$map, $key, $keys...", (arguments) {
  var map = arguments[0].assertMap("map");
  var keys = [arguments[1], ...arguments[2].asList];
  for (var key in keys.take(keys.length - 1)) {
    var value = map.contents[key];
    if (value is SassMap) {
      map = value;
    } else {
      return sassNull;
    }
  }
  return map.contents[keys.last] ?? sassNull;
});

final _set = BuiltInCallable.overloadedFunction("set", {
  r"$map, $key, $value": (arguments) {
    var map = arguments[0].assertMap("map");
    return _modify(map, [arguments[1]], (oldValue) => arguments[2]);
  },
  r"$map, $args...": (arguments) {
    var map = arguments[0].assertMap("map");
    var args = arguments[1].asList;
    if (args.isEmpty) {
      throw SassScriptException("Expected \$args to contain a key.");
    } else if (args.length == 1) {
      throw SassScriptException("Expected \$args to contain a value.");
    }
    return _modify(
        map, args.sublist(0, args.length - 1), (oldValue) => args.last);
  },
});

final _merge = BuiltInCallable.overloadedFunction("merge", {
  r"$map1, $map2": (arguments) {
    var map1 = arguments[0].assertMap("map1");
    var map2 = arguments[1].assertMap("map2");
    return SassMap({...map1.contents, ...map2.contents});
  },
  r"$map1, $args...": (arguments) {
    var map1 = arguments[0].assertMap("map1");
    var args = arguments[1].asList;
    if (args.isEmpty) {
      throw SassScriptException("Expected \$args to contain a key.");
    } else if (args.length == 1) {
      throw SassScriptException("Expected \$args to contain a map.");
    }
    var keys = args.sublist(0, args.length - 1);
    var map2 = args.last.assertMap("map2");
    SassMap _mergeCallback(Value oldMap) {
      // If oldMap is null, this indicates there is no nested map at the key.
      // If this is the case, set the value at the key to map2, which is akin to
      // merging map2 into an empty map. This behavior is consistent with that
      // of map.set().
      return (oldMap == null)
          ? map2
          : SassMap({...oldMap.assertMap().contents, ...map2.contents});
    }

    return _modify(map1, keys, _mergeCallback);
  },
});

final _deepMerge = _function("deep-merge", r"$map1, $map2", (arguments) {
  var map1 = arguments[0].assertMap("map1");
  var map2 = arguments[1].assertMap("map2");
  return _deepMergeImpl(map1, map2);
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
  for (var key in keys.take(keys.length - 1)) {
    var value = map.contents[key];
    if (value is SassMap) {
      map = value;
    } else {
      return sassFalse;
    }
  }
  return SassBoolean(map.contents.containsKey(keys.last));
});

/// Updates the specified value in [map] by applying the [modify()] callback to
/// it, then returns the resulting map.
///
/// If more than one key is provided, this means the map targeted for update is
/// nested within [map]. The multiple [keys] form a path of nested maps that
/// leads to the targeted map. If any value along the path is not a map, and
/// [overwrite] is true, this inserts a new map at that key and overwrites the
/// current value. Otherwise, this fails and returns [map] with no changes.
SassMap _modify(SassMap map, List<Value> keys, Value modify(Value old),
    [bool overwrite = true]) {
  SassMap _modifyNestedMap(SassMap map, int index) {
    var mutableMap = Map.of(map.contents);
    var key = keys[index];

    if (index == keys.length - 1) {
      mutableMap[key] = modify(mutableMap[key]);
      return SassMap(mutableMap);
    }

    var nestedMap = mutableMap[key].tryMap();
    if (nestedMap == null && !overwrite) {
      return SassMap(mutableMap);
    }

    nestedMap ??= const SassMap.empty();
    mutableMap[key] = _modifyNestedMap(nestedMap, index + 1);
    return SassMap(mutableMap);
  }

  return _modifyNestedMap(map, 0);
}

/// Merges [map1] and [map2], with values in [map2] taking precedence.
///
/// If both [map1] and [map2] have a map value associated with the same key,
/// this recursively merges those maps as well.
SassMap _deepMergeImpl(SassMap map1, SassMap map2) {
  if (map2.contents.isEmpty) return map1;

  // Avoid making a mutable copy of `map2` if it would totally overwrite `map1`
  // anyway.
  var mutable = false;
  var result = map2.contents;
  void _ensureMutable() {
    if (mutable) return;
    mutable = true;
    result = Map.of(result);
  }

  // Because values in `map2` take precedence over `map1`, we just check if any
  // entires in `map1` don't have corresponding keys in `map2`, or if they're
  // maps that need to be merged in their own right.
  map1.contents.forEach((key, value) {
    var resultValue = result[key];
    if (resultValue == null) {
      _ensureMutable();
      result[key] = value;
    } else {
      var resultMap = resultValue.tryMap();
      var valueMap = value.tryMap();

      if (resultMap != null && valueMap != null) {
        var merged = _deepMergeImpl(valueMap, resultMap);
        if (identical(merged, resultMap)) return;

        _ensureMutable();
        result[key] = merged;
      }
    }
  });

  return mutable ? SassMap(result) : map2;
}

/// Like [new BuiltInCallable.function], but always sets the URL to `sass:map`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:map");
