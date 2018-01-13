// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart' as internal;
import 'value.dart';

/// A SassScript color.
abstract class SassColor extends Value {
  /// This color's red channel, between `0` and `255`.
  int get red;

  /// This color's green channel, between `0` and `255`.
  int get green;

  /// This color's blue channel, between `0` and `255`.
  int get blue;

  /// This color's hue, between `0` and `360`.
  num get hue;

  /// This color's saturation, a percentage between `0` and `100`.
  num get saturation;

  /// This color's lightness, a percentage between `0` and `100`.
  num get lightness;

  /// This color's alpha channel, between `0` and `1`.
  num get alpha;

  /// Creates an RGB color.
  ///
  /// Throws a [RangeError] if [red], [green], and [blue] aren't between `0` and
  /// `255`, or if [alpha] isn't between `0` and `1`.
  factory SassColor.rgb(int red, int green, int blue, [num alpha]) =
      internal.SassColor.rgb;

  /// Creates an HSL color.
  ///
  /// Throws a [RangeError] if [saturation] or [lightness] aren't between `0`
  /// and `100`, or if [alpha] isn't between `0` and `1`.
  factory SassColor.hsl(num hue, num saturation, num lightness, [num alpha]) =
      internal.SassColor.hsl;

  /// Changes one or more of this color's RGB channels and returns the result.
  SassColor changeRgb({int red, int green, int blue, num alpha});

  /// Changes one or more of this color's HSL channels and returns the result.
  SassColor changeHsl({num hue, num saturation, num lightness, num alpha});

  /// Returns a new copy of this color with the alpha channel set to [alpha].
  SassColor changeAlpha(num alpha);
}
