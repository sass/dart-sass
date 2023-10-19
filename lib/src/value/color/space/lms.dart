// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../util/number.dart';
import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The LMS color space.
///
/// This only used as an intermediate space for conversions to and from OKLab
/// and OKLCH. It's never used in a real color value and isn't returned by
/// [ColorSpace.fromName].
///
/// @nodoc
@internal
final class LmsColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const LmsColorSpace()
      : super('lms', const [
          LinearChannel('long', 0, 1),
          LinearChannel('medium', 0, 1),
          LinearChannel('short', 0, 1)
        ]);

  SassColor convert(ColorSpace dest, double? long, double? medium,
      double? short, double? alpha,
      {bool missingLightness = false,
      bool missingChroma = false,
      bool missingHue = false,
      bool missingA = false,
      bool missingB = false}) {
    switch (dest) {
      case ColorSpace.oklab:
        // Algorithm from https://drafts.csswg.org/css-color-4/#color-conversion-code
        var longScaled = _cubeRootPreservingSign(long ?? 0);
        var mediumScaled = _cubeRootPreservingSign(medium ?? 0);
        var shortScaled = _cubeRootPreservingSign(short ?? 0);
        var lightness = lmsToOklab[0] * longScaled +
            lmsToOklab[1] * mediumScaled +
            lmsToOklab[2] * shortScaled;

        return SassColor.oklab(
            missingLightness ? null : lightness,
            missingA || fuzzyEquals(lightness, 0)
                ? null
                : lmsToOklab[3] * longScaled +
                    lmsToOklab[4] * mediumScaled +
                    lmsToOklab[5] * shortScaled,
            missingB || fuzzyEquals(lightness, 0)
                ? null
                : lmsToOklab[6] * longScaled +
                    lmsToOklab[7] * mediumScaled +
                    lmsToOklab[8] * shortScaled,
            alpha);

      case ColorSpace.oklch:
        // This is equivalent to converting to OKLab and then to OKLCH, but we
        // do it inline to avoid extra list allocations since we expect
        // conversions to and from OKLCH to be very common.
        var longScaled = _cubeRootPreservingSign(long ?? 0);
        var mediumScaled = _cubeRootPreservingSign(medium ?? 0);
        var shortScaled = _cubeRootPreservingSign(short ?? 0);
        return labToLch(
            dest,
            missingLightness
                ? null
                : lmsToOklab[0] * longScaled +
                    lmsToOklab[1] * mediumScaled +
                    lmsToOklab[2] * shortScaled,
            lmsToOklab[3] * longScaled +
                lmsToOklab[4] * mediumScaled +
                lmsToOklab[5] * shortScaled,
            lmsToOklab[6] * longScaled +
                lmsToOklab[7] * mediumScaled +
                lmsToOklab[8] * shortScaled,
            alpha,
            missingChroma: missingChroma,
            missingHue: missingHue);

      default:
        return super.convertLinear(dest, long, medium, short, alpha,
            missingLightness: missingLightness,
            missingChroma: missingChroma,
            missingHue: missingHue,
            missingA: missingA,
            missingB: missingB);
    }
  }

  /// Returns the cube root of the absolute value of [number] with the same sign
  /// as [number].
  double _cubeRootPreservingSign(double number) =>
      math.pow(number.abs(), 1 / 3) * number.sign;

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.srgbLinear ||
        ColorSpace.srgb ||
        ColorSpace.rgb =>
          lmsToLinearSrgb,
        ColorSpace.a98Rgb => lmsToLinearA98Rgb,
        ColorSpace.prophotoRgb => lmsToLinearProphotoRgb,
        ColorSpace.displayP3 => lmsToLinearDisplayP3,
        ColorSpace.rec2020 => lmsToLinearRec2020,
        ColorSpace.xyzD65 => lmsToXyzD65,
        ColorSpace.xyzD50 => lmsToXyzD50,
        _ => super.transformationMatrix(dest)
      };
}
