// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'dart:js_util';

import '../../value.dart';
import '../utils.dart';
import '../value.dart';

@JS()
class _NodeSassMap {
  external SassMap get dartValue;
  external set dartValue(SassMap dartValue);
}

/// Creates a new `sass.types.Map` object wrapping [value].
Object newNodeSassMap(SassMap value) =>
    callConstructor(mapConstructor, [null, value]);

/// The JS constructor for the `sass.types.Map` class.
final Function mapConstructor =
    createClass((_NodeSassMap thisArg, int length, [SassMap dartValue]) {
  thisArg.dartValue = dartValue ??
      SassMap(Map.fromIterables(Iterable.generate(length, (i) => SassNumber(i)),
          Iterable.generate(length, (_) => sassNull)));
}, {
  'getKey': (_NodeSassMap thisArg, int index) =>
      wrapValue(thisArg.dartValue.contents.keys.elementAt(index)),
  'getValue': (_NodeSassMap thisArg, int index) =>
      wrapValue(thisArg.dartValue.contents.values.elementAt(index)),
  'getLength': (_NodeSassMap thisArg) => thisArg.dartValue.contents.length,
  'setKey': (_NodeSassMap thisArg, int index, Object key) {
    var oldMap = thisArg.dartValue.contents;
    RangeError.checkValidIndex(index, oldMap, "index");

    var newKey = unwrapValue(key);
    var newMap = <Value, Value>{};
    var i = 0;
    for (var oldKey in thisArg.dartValue.contents.keys) {
      if (i == index) {
        newMap[newKey] = oldMap[oldKey];
      } else {
        if (newKey == oldKey) {
          throw ArgumentError.value(key, 'key', "is already in the map");
        }
        newMap[oldKey] = oldMap[oldKey];
      }
      i++;
    }

    thisArg.dartValue = SassMap(newMap);
  },
  'setValue': (_NodeSassMap thisArg, int index, Object value) {
    var key = thisArg.dartValue.contents.keys.elementAt(index);
    thisArg.dartValue =
        SassMap({...thisArg.dartValue.contents, key: unwrapValue(value)});
  },
  'toString': (_NodeSassMap thisArg) => thisArg.dartValue.toString()
});
