// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'package:meta/meta.dart';

import '../../color.dart';
import 'utils.dart';

/// The legacy HSL color space.
///
/// @nodoc
@internal
class HslColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;
  bool get isStrictlyBoundedInternal => true;
  bool get isLegacyInternal => true;
  bool get isPolarInternal => true;

  const HslColorSpace()
      : super('hsl', const [
          hueChannel,
          LinearChannel('saturation', 0, 100, requiresPercent: true),
          LinearChannel('lightness', 0, 100, requiresPercent: true)
        ]);

  SassColor convert(ColorSpace dest, double? hue, double? saturation,
      double? lightness, double alpha) {
    // Algorithm from the CSS3 spec: https://www.w3.org/TR/css3-color/#hsl-color.
    var scaledHue = ((hue ?? 0) / 360) % 1;
    var scaledSaturation = (saturation ?? 0) / 100;
    var scaledLightness = (lightness ?? 0) / 100;

    var m2 = scaledLightness <= 0.5
        ? scaledLightness * (scaledSaturation + 1)
        : scaledLightness +
            scaledSaturation -
            scaledLightness * scaledSaturation;
    var m1 = scaledLightness * 2 - m2;

    return forwardMissingChannels(
        ColorSpace.srgb.convert(
            dest,
            hueToRgb(m1, m2, scaledHue + 1 / 3),
            hueToRgb(m1, m2, scaledHue),
            hueToRgb(m1, m2, scaledHue - 1 / 3),
            alpha),
        missingLightness: lightness == null,
        missingColorfulness: saturation == null,
        missingHue: hue == null);
  }
}
