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

        // Algorithm from https://en.wikipedia.org/wiki/HSL_and_HSV#RGB_to_HSL_and_HSV
        var max = math.max(math.max(red, green), blue);
        var min = math.min(math.min(red, green), blue);
        var delta = max - min;

        double? hue;
        if (max == min) {
          hue = 0;
        } else if (max == red) {
          hue = (60 * (green - blue) / delta) % 360;
        } else if (max == green) {
          hue = (120 + 60 * (blue - red) / delta) % 360;
        } else {
          // max == blue
          hue = (240 + 60 * (red - green) / delta) % 360;
        }

        if (dest == ColorSpace.hsl) {
          var lightness = fuzzyClamp(50 * (max + min), 0, 100);

          double? saturation;
          if (lightness == 0 || lightness == 100) {
            saturation = null;
          } else if (fuzzyEquals(max, min)) {
            saturation = 0;
          } else if (lightness < 50) {
            saturation = 100 * delta / (max + min);
          } else {
            saturation = 100 * delta / (2 - max - min);
          }
          saturation = saturation
              .andThen((saturation) => fuzzyClamp(saturation, 0, 100));

          return SassColor.forSpaceInternal(
              dest,
              missingHue || saturation == 0 || saturation == null ? null : hue,
              missingChroma ? null : saturation,
              missingLightness ? null : lightness,
              alpha);
        } else {
          var whiteness = fuzzyClamp(min * 100, 0, 100);
          var blackness = fuzzyClamp(100 - max * 100, 0, 100);
          return SassColor.forSpaceInternal(
              dest,
              missingHue || fuzzyEquals(whiteness + blackness, 100)
                  ? null
                  : hue,
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
