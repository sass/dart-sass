// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS('immutable.List')
class ImmutableList {
  external factory ImmutableList([List<Object?>? contents]);

  external List<Object?> toArray();
}

@JS('immutable.OrderedMap')
class ImmutableMap {
  external factory ImmutableMap([List<List<Object?>>? entries]);

  external ImmutableMap asMutable();
  external ImmutableMap asImmutable();
  external ImmutableMap set(Object key, Object? value);
  external Object toObject();
  external void forEach(void Function(Object?, Object, Object?) callback);
}

@JS('immutable.isList')
external bool isImmutableList(Object? object);

@JS('immutable.isOrderedMap')
external bool isImmutableMap(Object? object);

/// Converts [list], which may be either a JavaScript `Array` or an
/// [ImmutableList], into a Dart [List].
List<Object?> jsToDartList(Object? list) =>
    isImmutableMap(list) ? (list as ImmutableList).toArray() : list as List;

/// Converts a Dart map into an equivalent [ImmutableMap].
ImmutableMap dartMapToImmutableMap(Map<Object, Object?> dartMap) {
  var immutableMap = ImmutableMap().asMutable();
  for (var entry in dartMap.entries) {
    immutableMap = immutableMap.set(entry.key, entry.value);
  }
  return immutableMap.asImmutable();
}

/// Converts an [ImmutableMap] into an equivalent Dart map.
Map<Object, Object?> immutableMapToDartMap(ImmutableMap immutableMap) {
  var dartMap = <Object, Object?>{};
  immutableMap.forEach(allowInterop((value, key, _) {
    dartMap[key] = value;
  }));
  return dartMap;
}
