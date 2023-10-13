// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../../../util/number.dart';
import '../../color.dart';

/// A constant used to convert Lab to/from XYZ.
const labKappa = 24389 / 27; // 29^3/3^3;

/// A constant used to convert Lab to/from XYZ.
const labEpsilon = 216 / 24389; // 6^3/29^3;

/// The hue channel shared across all polar color spaces.
const hueChannel =
    ColorChannel('hue', isPolarAngle: true, associatedUnit: 'deg');

/// The color channels shared across all RGB color spaces (except the legacy RGB space).
const rgbChannels = [
  LinearChannel('red', 0, 1),
  LinearChannel('green', 0, 1),
  LinearChannel('blue', 0, 1)
];

/// The color channels shared across both XYZ color spaces.
const xyzChannels = [
  LinearChannel('x', 0, 1),
  LinearChannel('y', 0, 1),
  LinearChannel('z', 0, 1)
];

/// Converts a legacy HSL/HWB hue to an RGB channel.
///
/// The algorithm comes from from the CSS3 spec:
/// http://www.w3.org/TR/css3-color/#hsl-color.
double hueToRgb(double m1, double m2, double hue) {
  if (hue < 0) hue += 1;
  if (hue > 1) hue -= 1;

  return switch (hue) {
    < 1 / 6 => m1 + (m2 - m1) * hue * 6,
    < 1 / 2 => m2,
    < 2 / 3 => m1 + (m2 - m1) * (2 / 3 - hue) * 6,
    _ => m1
  };
}

/// The algorithm for converting a single `srgb` or `display-p3` channel to
/// linear-light form.
double srgbAndDisplayP3ToLinear(double channel) {
  // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
  var abs = channel.abs();
  return abs < 0.04045
      ? channel / 12.92
      : channel.sign * math.pow((abs + 0.055) / 1.055, 2.4);
}

/// The algorithm for converting a single `srgb` or `display-p3` channel to
/// gamma-corrected form.
double srgbAndDisplayP3FromLinear(double channel) {
  // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
  var abs = channel.abs();
  return abs <= 0.0031308
      ? channel * 12.92
      : channel.sign * (1.055 * math.pow(abs, 1 / 2.4) - 0.055);
}

/// Converts a Lab or OKLab color to LCH or OKLCH, respectively.
SassColor labToLch(
    ColorSpace dest, double lightness, double a, double b, double alpha) {
  // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
  if (fuzzyEquals(lightness, 0)) {
    return SassColor.forSpaceInternal(dest, 0, null, null, alpha);
  }

  var chroma = math.sqrt(math.pow(a, 2) + math.pow(b, 2));
  var hue = fuzzyEquals(chroma, 0) ? null : math.atan2(b, a) * 180 / math.pi;

  return SassColor.forSpaceInternal(dest, lightness, chroma,
      hue == null || hue >= 0 ? hue : hue + 360, alpha);
}
