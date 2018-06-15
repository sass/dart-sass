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
      new SassMap(new Map.fromIterables(
          new Iterable.generate(length, (i) => new SassNumber(i)),
          new Iterable.generate(length, (_) => sassNull)));
}, {
  'getKey': (_NodeSassMap thisArg, int index) =>
      wrapValue(thisArg.dartValue.contents.keys.elementAt(index)),
  'getValue': (_NodeSassMap thisArg, int index) =>
      wrapValue(thisArg.dartValue.contents.values.elementAt(index)),
  'getLength': (_NodeSassMap thisArg) => thisArg.dartValue.contents.length,
  'setKey': (_NodeSassMap thisArg, int index, key) {
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
          throw new ArgumentError.value(key, 'key', "is already in the map");
        }
        newMap[oldKey] = oldMap[oldKey];
      }
      i++;
    }

    thisArg.dartValue = new SassMap(newMap);
  },
  'setValue': (_NodeSassMap thisArg, int index, value) {
    var key = thisArg.dartValue.contents.keys.elementAt(index);

    var mutable = new Map.of(thisArg.dartValue.contents);
    mutable[key] = unwrapValue(value);
    thisArg.dartValue = new SassMap(mutable);
  },
  'toString': (_NodeSassMap thisArg) => thisArg.dartValue.toString()
});
