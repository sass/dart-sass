// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../hybrid/value/string.dart';
import '../value.dart';

extension type JSSassLegacyString._(JSLegacyValue _) implements JSLegacyValue {
  /// The JS `sass.types.String` class.
  static final jsClass = JSClass<JSSassLegacyString>(
      (
        JSSassLegacyString self,
        String? value, [
        UnsafeDartWrapper<SassString>? modernValue,
      ]) {
        // Either [modernValue] or [value] must be passed.
        self.modernValue =
            modernValue ?? SassString(value!, quotes: false).toJS;
      }.toJSCaptureThis,
      name: 'sass.types.String')
    ..defineMethods({
      'getValue':
          ((JSSassLegacyString self) => self.toDart.text).toJSCaptureThis,
      'setValue': (JSSassLegacyString self, String value) {
        self.modernValue = SassString(value, quotes: false).toJS;
      }.toJSCaptureThis,
    });

  @JS('dartValue')
  external UnsafeDartWrapper<SassString> modernValue;

  SassString get toDart => modernValue.toDart;
}

extension SassStringToJSLegacy on SassString {
  JSSassLegacyString get toJSLegacy =>
      JSSassLegacyString.jsClass.construct(null, toJS);
}
