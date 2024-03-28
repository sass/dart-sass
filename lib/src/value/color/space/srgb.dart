// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:math' as math;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../util/nullable.dart';
import '../../../util/number.dart';
import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The sRGB color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-sRGB
///
/// @nodoc
@internal
final class SrgbColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const SrgbColorSpace() : super('srgb', rgbChannels);

  SassColor convert(
      ColorSpace dest, double? red, double? green, double? blue, double? alpha,
      {bool missingLightness = false,
      bool missingChroma = false,
      bool missingHue = false}) {
    switch (dest) {
      case ColorSpace.hsl || ColorSpace.hwb:
        red ??= 0;
        green ??= 0;
        blue ??= 0;

        // Algorithm from https://drafts.csswg.org/css-color-4/#rgb-to-hsl
        var max = math.max(math.max(red, green), blue);
        var min = math.min(math.min(red, green), blue);
        var delta = max - min;

        double hue;
        if (max == min) {
          hue = 0;
        } else if (max == red) {
          hue = 60 * (green - blue) / delta + 360;
        } else if (max == green) {
          hue = 60 * (blue - red) / delta + 120;
        } else {
          // max == blue
          hue = 60 * (red - green) / delta + 240;
        }

        if (dest == ColorSpace.hsl) {
          var lightness = (min + max) / 2;

          var saturation = lightness == 0 || lightness == 1
              ? 0.0
              : 100 * (max - lightness) / math.min(lightness, 1 - lightness);
          if (saturation < 0) {
            hue += 180;
            saturation = saturation.abs();
          }

          return SassColor.forSpaceInternal(
              dest,
              missingHue || fuzzyEquals(saturation, 0) ? null : hue % 360,
              missingChroma ? null : saturation,
              missingLightness ? null : lightness * 100,
              alpha);
        } else {
          var whiteness = min * 100;
          var blackness = 100 - max * 100;
          return SassColor.forSpaceInternal(
              dest,
              missingHue || fuzzyGreaterThanOrEquals(whiteness + blackness, 100)
                  ? null
                  : hue % 360,
              whiteness,
              blackness,
              alpha);
        }

      case ColorSpace.rgb:
        return SassColor.rgb(
            red == null ? null : red * 255,
            green == null ? null : green * 255,
            blue == null ? null : blue * 255,
            alpha);

      case ColorSpace.srgbLinear:
        return SassColor.forSpaceInternal(dest, red.andThen(toLinear),
            green.andThen(toLinear), blue.andThen(toLinear), alpha);

      default:
        return super.convertLinear(dest, red, green, blue, alpha,
            missingLightness: missingLightness,
            missingChroma: missingChroma,
            missingHue: missingHue);
    }
  }

  @protected
  double toLinear(double channel) => srgbAndDisplayP3ToLinear(channel);

  @protected
  double fromLinear(double channel) => srgbAndDisplayP3FromLinear(channel);

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.displayP3 => linearSrgbToLinearDisplayP3,
        ColorSpace.a98Rgb => linearSrgbToLinearA98Rgb,
        ColorSpace.prophotoRgb => linearSrgbToLinearProphotoRgb,
        ColorSpace.rec2020 => linearSrgbToLinearRec2020,
        ColorSpace.xyzD65 => linearSrgbToXyzD65,
        ColorSpace.xyzD50 => linearSrgbToXyzD50,
        ColorSpace.lms => linearSrgbToLms,
        _ => super.transformationMatrix(dest),
      };
}
