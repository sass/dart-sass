// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../conversions.dart';
import '../space.dart';
import 'utils.dart';

/// The a98-rgb color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-a98-rgb
///
/// @nodoc
@internal
final class const A98RgbColorSpace() extends ColorSpace {
  @override
  bool get isBoundedInternal => true;

  this : super('a98-rgb', rgbChannels);

  @override
  @protected
  double toLinear(double channel) =>
      // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
      channel.sign * math.pow(channel.abs(), 563 / 256);

  @override
  @protected
  double fromLinear(double channel) =>
      // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
      channel.sign * math.pow(channel.abs(), 256 / 563);

  @override
  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
    .srgbLinear || .srgb || .rgb => linearA98RgbToLinearSrgb,
    .displayP3 || .displayP3Linear => linearA98RgbToLinearDisplayP3,
    .prophotoRgb => linearA98RgbToLinearProphotoRgb,
    .rec2020 => linearA98RgbToLinearRec2020,
    .xyzD65 => linearA98RgbToXyzD65,
    .xyzD50 => linearA98RgbToXyzD50,
    .lms => linearA98RgbToLms,
    _ => super.transformationMatrix(dest),
  };
}
