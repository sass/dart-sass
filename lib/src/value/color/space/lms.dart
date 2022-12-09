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
class LmsColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const LmsColorSpace()
      : super('lms', const [
          LinearChannel('long', 0, 1),
          LinearChannel('medium', 0, 1),
          LinearChannel('short', 0, 1)
        ]);

  SassColor convert(
      ColorSpace dest, double long, double medium, double short, double alpha) {
    switch (dest) {
      case ColorSpace.oklab:
        // Algorithm from https://drafts.csswg.org/css-color-4/#color-conversion-code
        var longScaled = math.pow(long, 1 / 3);
        var mediumScaled = math.pow(medium, 1 / 3);
        var shortScaled = math.pow(short, 1 / 3);
        var lightness = lmsToOklab[0] * longScaled +
            lmsToOklab[1] * mediumScaled +
            lmsToOklab[2] * shortScaled;

        return SassColor.oklab(
            lightness,
            fuzzyEquals(lightness, 0)
                ? null
                : lmsToOklab[3] * longScaled +
                    lmsToOklab[4] * mediumScaled +
                    lmsToOklab[5] * shortScaled,
            fuzzyEquals(lightness, 0)
                ? null
                : lmsToOklab[6] * longScaled +
                    lmsToOklab[7] * mediumScaled +
                    lmsToOklab[8] * shortScaled,
            alpha);

      case ColorSpace.oklch:
        // This is equivalent to converting to OKLab and then to OKLCH, but we
        // do it inline to avoid extra list allocations since we expect
        // conversions to and from OKLCH to be very common.
        var longScaled = math.pow(long, 1 / 3);
        var mediumScaled = math.pow(medium, 1 / 3);
        var shortScaled = math.pow(short, 1 / 3);
        return labToLch(
            dest,
            lmsToOklab[0] * longScaled +
                lmsToOklab[1] * mediumScaled +
                lmsToOklab[2] * shortScaled,
            lmsToOklab[3] * longScaled +
                lmsToOklab[4] * mediumScaled +
                lmsToOklab[5] * shortScaled,
            lmsToOklab[6] * longScaled +
                lmsToOklab[7] * mediumScaled +
                lmsToOklab[8] * shortScaled,
            alpha);

      default:
        return super.convert(dest, long, medium, short, alpha);
    }
  }

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

  @protected
  Float64List transformationMatrix(ColorSpace dest) {
    switch (dest) {
      case ColorSpace.srgbLinear:
      case ColorSpace.srgb:
      case ColorSpace.rgb:
        return lmsToLinearSrgb;
      case ColorSpace.a98Rgb:
        return lmsToLinearA98Rgb;
      case ColorSpace.prophotoRgb:
        return lmsToLinearProphotoRgb;
      case ColorSpace.displayP3:
        return lmsToLinearDisplayP3;
      case ColorSpace.rec2020:
        return lmsToLinearRec2020;
      case ColorSpace.xyzD65:
        return lmsToXyzD65;
      case ColorSpace.xyzD50:
        return lmsToXyzD50;
      default:
        return super.transformationMatrix(dest);
    }
  }
}
