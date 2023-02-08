// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../color.dart';
import '../../../util/nullable.dart';
import '../conversions.dart';
import 'utils.dart';

/// The linear-light sRGB color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-sRGB-linear
///
/// @nodoc
@internal
class SrgbLinearColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const SrgbLinearColorSpace() : super('srgb-linear', rgbChannels);

  SassColor convert(
      ColorSpace dest, double? red, double? green, double? blue, double alpha) {
    switch (dest) {
      case ColorSpace.rgb:
      case ColorSpace.hsl:
      case ColorSpace.hwb:
      case ColorSpace.srgb:
        return ColorSpace.srgb.convert(
            dest,
            red.andThen(srgbAndDisplayP3FromLinear),
            green.andThen(srgbAndDisplayP3FromLinear),
            blue.andThen(srgbAndDisplayP3FromLinear),
            alpha);

      default:
        return super.convert(dest, red, green, blue, alpha);
    }
  }

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

  @protected
  Float64List transformationMatrix(ColorSpace dest) {
    switch (dest) {
      case ColorSpace.displayP3:
        return linearSrgbToLinearDisplayP3;
      case ColorSpace.a98Rgb:
        return linearSrgbToLinearA98Rgb;
      case ColorSpace.prophotoRgb:
        return linearSrgbToLinearProphotoRgb;
      case ColorSpace.rec2020:
        return linearSrgbToLinearRec2020;
      case ColorSpace.xyzD65:
        return linearSrgbToXyzD65;
      case ColorSpace.xyzD50:
        return linearSrgbToXyzD50;
      case ColorSpace.lms:
        return linearSrgbToLms;
      default:
        return super.transformationMatrix(dest);
    }
  }
}
