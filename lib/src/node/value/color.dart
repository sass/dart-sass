// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';

import '../../value.dart';
import '../utils.dart';

@JS()
class _NodeSassColor {
  external SassColor get dartValue;
  external set dartValue(SassColor dartValue);
}

/// Creates a new `sass.types.Color` object wrapping [value].
Object newNodeSassColor(SassColor value) =>
    callConstructor(colorConstructor, [null, null, null, null, value]);

/// The JS constructor for the `sass.types.Color` class.
final Function colorConstructor = createClass(
    (_NodeSassColor thisArg, num redOrArgb,
        [num green, num blue, num alpha, SassColor dartValue]) {
  if (dartValue != null) {
    thisArg.dartValue = dartValue;
    return;
  }

  // This has two signatures:
  //
  // * `new sass.types.Color(red, green, blue, [alpha])`
  // * `new sass.types.Color(argb)`
  //
  // The latter takes an integer that's interpreted as the hex value 0xAARRGGBB.
  num red;
  if (green == null) {
    var argb = redOrArgb as int;
    alpha = (argb >> 24) / 0xff;
    red = (argb >> 16) % 0x100;
    green = (argb >> 8) % 0x100;
    blue = argb % 0x100;
  } else {
    red = redOrArgb;
  }

  thisArg.dartValue = new SassColor.rgb(
      _clamp(red), _clamp(green), _clamp(blue), alpha?.clamp(0, 1) ?? 1);
}, {
  'getR': (_NodeSassColor thisArg) => thisArg.dartValue.red,
  'getG': (_NodeSassColor thisArg) => thisArg.dartValue.green,
  'getB': (_NodeSassColor thisArg) => thisArg.dartValue.blue,
  'getA': (_NodeSassColor thisArg) => thisArg.dartValue.alpha,
  'setR': (_NodeSassColor thisArg, num value) {
    thisArg.dartValue = thisArg.dartValue.changeRgb(red: _clamp(value));
  },
  'setG': (_NodeSassColor thisArg, num value) {
    thisArg.dartValue = thisArg.dartValue.changeRgb(green: _clamp(value));
  },
  'setB': (_NodeSassColor thisArg, num value) {
    thisArg.dartValue = thisArg.dartValue.changeRgb(blue: _clamp(value));
  },
  'setA': (_NodeSassColor thisArg, num value) {
    thisArg.dartValue = thisArg.dartValue.changeRgb(alpha: value.clamp(0, 1));
  },
  'toString': (_NodeSassColor thisArg) => thisArg.dartValue.toString()
});

/// Clamps [channel] within the range 0, 255 and rounds it to the nearest
/// integer.
int _clamp(num channel) => channel.clamp(0, 255).round();
