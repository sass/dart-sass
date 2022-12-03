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
class A98RgbColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const A98RgbColorSpace() : super('a98-rgb', rgbChannels);

  @protected
  double toLinear(double channel) =>
      // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
      channel.sign * math.pow(channel.abs(), 563 / 256);

  @protected
  double fromLinear(double channel) =>
      // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
      channel.sign * math.pow(channel.abs(), 256 / 563);

  @protected
  Float64List transformationMatrix(ColorSpace dest) {
    switch (dest) {
      case ColorSpace.srgbLinear:
      case ColorSpace.srgb:
      case ColorSpace.rgb:
        return linearA98RgbToLinearSrgb;
      case ColorSpace.displayP3:
        return linearA98RgbToLinearDisplayP3;
      case ColorSpace.prophotoRgb:
        return linearA98RgbToLinearProphotoRgb;
      case ColorSpace.rec2020:
        return linearA98RgbToLinearRec2020;
      case ColorSpace.xyzD65:
        return linearA98RgbToXyzD65;
      case ColorSpace.xyzD50:
        return linearA98RgbToXyzD50;
      case ColorSpace.lms:
        return linearA98RgbToLms;
      default:
        return super.transformationMatrix(dest);
    }
  }
}
