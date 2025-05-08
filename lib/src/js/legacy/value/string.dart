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
extension type JSSassLegacyString._(JSObject _) implements JSObject {
  /// The JS `sass.types.String` class.
  static final jsClass = JSClass<JSSassLegacyString>('sass.types.String', (
    JSSassLegacyString self,
    String? value, [
    JSSassString? modernValue,
  ]) {
    // Either [modernValue] or [value] must be passed.
    self.modernValue = modernValue ?? SassString(value!, quotes: false).toJS;
  })
    ..defineMethods({
      'getValue': ((JSSassLegacyString self) => self.toDart.text).toJS,
      'setValue': (JSSassLegacyString self, String value) {
        self.modernValue = SassString(value, quotes: false).toJS;
      }.toJS,
    });

  external JSSassString modernValue;

  SassString get toDart => modernValue.toDart;
}

extension SassStringToJSLegacy on SassString {
  JSSassLegacyString get toJSLegacy =>
      JSSassLegacyString.jsClass.construct(null, this.toJS);
}
