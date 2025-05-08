// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/map.dart';
import '../../hybrid/value/map.dart';
import '../value.dart';

extension type JSSassLegacyMap._(JSLegacyValue _) implements JSLegacyValue {
  /// The JS `sass.types.Map` class.
  static final jsClass = JSClass<JSSassLegacyMap>(
      (
        JSSassLegacyMap self,
        int? length, [
        UnsafeDartWrapper<SassMap>? modernValue,
      ]) {
        self.modernValue = modernValue ??
            // Either [modernValue] or [length] must be passed.
            SassMap({for (var i = 0; i < length!; i++) SassNumber(i): sassNull})
                .toJS;
      }.toJSCaptureThis,
      name: 'sass.types.Map')
    ..defineMethods({
      'getKey': ((JSSassLegacyMap self, int index) =>
              self.toDart.contents.keys.elementAt(index).toJSLegacy)
          .toJSCaptureThis,
      'getValue': ((JSSassLegacyMap self, int index) =>
              self.toDart.contents.values.elementAt(index).toJSLegacy)
          .toJSCaptureThis,
      'getLength': ((JSSassLegacyMap self) => self.toDart.contents.length)
          .toJSCaptureThis,
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
      }.toJSCaptureThis,
      'setValue': (JSSassLegacyMap self, int index, JSLegacyValue value) {
        var key = self.toDart.contents.keys.elementAt(index);
        self.modernValue = SassMap({
          ...self.toDart.contents,
          key: value.toDart,
        }).toJS;
      }.toJSCaptureThis,
    });

  @JS('dartValue')
  external UnsafeDartWrapper<SassMap> modernValue;

  SassMap get toDart => modernValue.toDart;
}

extension SassMapToJSLegacy on SassMap {
  JSSassLegacyMap get toJSLegacy =>
      JSSassLegacyMap.jsClass.construct(null, toJS);
}
