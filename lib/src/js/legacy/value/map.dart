// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

@anonymous
extension type JSSassLegacyMap._(JSObject _) implements JSObject {
  /// The JS `sass.types.Map` class.
  static final jsClass = JSClass<JSSassLegacyMap>('sass.types.Map', (
    JSSassLegacyMap self,
    int? length, [
    JSSassMap? modernValue,
  ]) {
    self.modernValue = modernValue ??
        SassMap({for (var i = 0; i < length; i++) SassNumber(i): sassNull})
            .toJS;
  })
    ..defineMethods({
      'getKey': ((JSSassLegacyMap self, int index) =>
          self.toDart.contents.keys.elementAt(index).toJSLegacy).toJS,
      'getValue': ((JSSassLegacyMap self, int index) =>
          self.toDart.contents.values.elementAt(index).toJSLegacy).toJS,
      'getLength': ((JSSassLegacyMap self) => self.toDart.contents.length).toJS,
      'setKey': (JSSassLegacyMap self, int index, JSLegacyValue key) {
        var oldMap = self.toDart.contents;
        RangeError.checkValidIndex(index, oldMap, "index");

        var newKey = key.toDart;
        var newMap = <Value, Value>{};
        var i = 0;
        for (var (oldKey, oldValue) in self.toDart.contents.pairs) {
          if (i == index) {
            newMap[newKey] = oldValue;
          } else {
            if (newKey == oldKey) {
              throw ArgumentError.value(key, 'key', "is already in the map");
            }
            newMap[oldKey] = oldValue;
          }
          i++;
        }

        self.modernValue = SassMap(newMap).toJS;
      }.toJS,
      'setValue': (JSSassLegacyMap self, int index, JSLegacyValue value) {
        var key = self.toDart.contents.keys.elementAt(index);
        self.modernValue = SassMap({
          ...self.modernValue.contents,
          key: value.toDart,
        }).toJS;
      }.toJS,
    });

  external SassMap modernValue;

  SassMap get toDart => modernValue.toDart;
}

extension SassMapToJSLegacy on SassMap {
  JSSassLegacyMap get toJSLegacy =>
      JSSassLegacyMap.jsClass.construct(null, null, this.toJS);
}
