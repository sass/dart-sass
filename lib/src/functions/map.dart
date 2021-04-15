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
  _get,
  _set,
  _merge,
  _remove,
  _keys,
  _values,
  _hasKey,
  _deepMerge,
  _deepRemove
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
    return _modify(map, [arguments[1]], (_) => arguments[2]);
  },
  r"$map, $args...": (arguments) {
    var map = arguments[0].assertMap("map");
    var args = arguments[1].asList;
    if (args.isEmpty) {
      throw SassScriptException("Expected \$args to contain a key.");
    } else if (args.length == 1) {
      throw SassScriptException("Expected \$args to contain a value.");
    }
    return _modify(map, args.sublist(0, args.length - 1), (_) => args.last);
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
    var map2 = args.last.assertMap("map2");
    return _modify(map1, args.take(args.length - 1), (oldValue) {
      var nestedMap = oldValue.tryMap();
      if (nestedMap == null) return map2;
      return SassMap({...nestedMap.contents, ...map2.contents});
    });
  },
});

final _deepMerge = _function("deep-merge", r"$map1, $map2", (arguments) {
  var map1 = arguments[0].assertMap("map1");
  var map2 = arguments[1].assertMap("map2");
  return _deepMergeImpl(map1, map2);
});

final _deepRemove =
    _function("deep-remove", r"$map, $key, $keys...", (arguments) {
  var map = arguments[0].assertMap("map");
  var keys = [arguments[1], ...arguments[2].asList];
  return _modify(map, keys.take(keys.length - 1), (value) {
    var nestedMap = value.tryMap();
    if (nestedMap != null && nestedMap.contents.containsKey(keys.last)) {
      return SassMap(Map.of(nestedMap.contents)..remove(keys.last));
    }
    return value;
  }, addNesting: false);
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

/// Updates the specified value in [map] by applying the [modify] callback to
/// it, then returns the resulting map.
///
/// If more than one key is provided, this means the map targeted for update is
/// nested within [map]. The multiple [keys] form a path of nested maps that
/// leads to the targeted value, which is passed to [modify].
///
/// If any value along the path (other than the last one) is not a map and
/// [addNesting] is `true`, this creates nested maps to match [keys] and passes
/// [sassNull] to [modify]. Otherwise, this fails and returns [map] with no
/// changes.
///
/// If no keys are provided, this passes [map] directly to modify and returns
/// the result.
Value _modify(SassMap map, Iterable<Value> keys, Value modify(Value old),
    {bool addNesting = true}) {
  var keyIterator = keys.iterator;
  SassMap _modifyNestedMap(SassMap map) {
    var mutableMap = Map.of(map.contents);
    var key = keyIterator.current;

    if (!keyIterator.moveNext()) {
      mutableMap[key] = modify(mutableMap[key] ?? sassNull);
      return SassMap(mutableMap);
    }

    var nestedMap = mutableMap[key]?.tryMap();
    if (nestedMap == null && !addNesting) return SassMap(mutableMap);

    mutableMap[key] = _modifyNestedMap(nestedMap ?? const SassMap.empty());
    return SassMap(mutableMap);
  }

  return keyIterator.moveNext() ? _modifyNestedMap(map) : modify(map);
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
  // entries in `map1` don't have corresponding keys in `map2`, or if they're
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
