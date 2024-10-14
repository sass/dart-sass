// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../util/nullable.dart';
import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The linear-light sRGB color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-sRGB-linear
///
/// @nodoc
@internal
final class SrgbLinearColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const SrgbLinearColorSpace() : super('srgb-linear', rgbChannels);

  SassColor convert(ColorSpace dest, double? red, double? green, double? blue,
          double? alpha) =>
      switch (dest) {
        ColorSpace.rgb ||
        ColorSpace.hsl ||
        ColorSpace.hwb ||
        ColorSpace.srgb =>
          ColorSpace.srgb.convert(
              dest,
              red.andThen(srgbAndDisplayP3FromLinear),
              green.andThen(srgbAndDisplayP3FromLinear),
              blue.andThen(srgbAndDisplayP3FromLinear),
              alpha),
        _ => super.convert(dest, red, green, blue, alpha)
      };

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.displayP3 => linearSrgbToLinearDisplayP3,
        ColorSpace.a98Rgb => linearSrgbToLinearA98Rgb,
        ColorSpace.prophotoRgb => linearSrgbToLinearProphotoRgb,
        ColorSpace.rec2020 => linearSrgbToLinearRec2020,
        ColorSpace.xyzD65 => linearSrgbToXyzD65,
        ColorSpace.xyzD50 => linearSrgbToXyzD50,
        ColorSpace.lms => linearSrgbToLms,
        _ => super.transformationMatrix(dest)
      };
}
