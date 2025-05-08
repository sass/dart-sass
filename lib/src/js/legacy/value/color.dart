// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../../util/number.dart';
import '../../hybrid/value/color.dart';
import '../value.dart';

extension type JSSassLegacyColor._(JSLegacyValue _) implements JSLegacyValue {
  /// The JS `sass.types.Color` class.
  static final jsClass = JSClass<JSSassLegacyColor>(
      (
        JSSassLegacyColor self,
        num? redOrArgb, [
        num? green,
        num? blue,
        num? alpha,
        UnsafeDartWrapper<SassColor>? modernValue,
      ]) {
        if (modernValue != null) {
          self.modernValue = modernValue;
          return;
        }

        // This has two signatures:
        //
        // * `new sass.types.Color(red, green, blue, [alpha])`
        // * `new sass.types.Color(argb)`
        //
        // The latter takes an integer that's interpreted as the hex value 0xAARRGGBB.
        num red;
        if (green == null || blue == null) {
          var argb = redOrArgb as int;
          alpha = (argb >> 24) / 0xff;
          red = (argb >> 16) % 0x100;
          green = (argb >> 8) % 0x100;
          blue = argb % 0x100;
        } else {
          // Either [modernValue] or [redOrArgb] must be passed.
          red = redOrArgb!;
        }

        self.modernValue = SassColor.rgb(
          _clamp(red),
          _clamp(green),
          _clamp(blue),
          alpha.andThen((alpha) => clampLikeCss(alpha.toDouble(), 0, 1)) ?? 1,
        ).toJS;
      }.toJSCaptureThis,
      name: 'sass.types.Color')
    ..defineMethods({
      'getR': ((JSSassLegacyColor self) => self.toDart.red).toJSCaptureThis,
      'getG': ((JSSassLegacyColor self) => self.toDart.green).toJSCaptureThis,
      'getB': ((JSSassLegacyColor self) => self.toDart.blue).toJSCaptureThis,
      'getA': ((JSSassLegacyColor self) => self.toDart.alpha).toJSCaptureThis,
      'setR': (JSSassLegacyColor self, num value) {
        self.modernValue = self.toDart.changeRgb(red: _clamp(value)).toJS;
      }.toJSCaptureThis,
      'setG': (JSSassLegacyColor self, num value) {
        self.modernValue = self.toDart.changeRgb(green: _clamp(value)).toJS;
      }.toJSCaptureThis,
      'setB': (JSSassLegacyColor self, num value) {
        self.modernValue = self.toDart.changeRgb(blue: _clamp(value)).toJS;
      }.toJSCaptureThis,
      'setA': (JSSassLegacyColor self, num value) {
        self.modernValue = self.toDart
            .changeRgb(
              alpha: clampLikeCss(value.toDouble(), 0, 1),
            )
            .toJS;
      }.toJSCaptureThis,
    });

  /// The value of the color in the modern JS API.
  @JS('dartValue')
  external UnsafeDartWrapper<SassColor> modernValue;

  SassColor get toDart => modernValue.toDart;
}

/// Clamps [channel] within the range 0, 255 and rounds it to the nearest
/// integer.
int _clamp(num channel) => fuzzyRound(clampLikeCss(channel.toDouble(), 0, 255));

extension SassColorToJSLegacy on SassColor {
  JSSassLegacyColor get toJSLegacy => JSSassLegacyColor.jsClass
      .constructVarArgs([null, null, null, null, toJS]);
}
