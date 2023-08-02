// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../conversions.dart';
import '../space.dart';
import 'utils.dart';

/// The prophoto-rgb color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-prophoto-rgb
///
/// @nodoc
@internal
class ProphotoRgbColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const ProphotoRgbColorSpace() : super('prophoto-rgb', rgbChannels);

  @protected
  double toLinear(double channel) {
    // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
    var abs = channel.abs();
    return abs <= 16 / 512 ? channel / 16 : channel.sign * math.pow(abs, 1.8);
  }

  @protected
  double fromLinear(double channel) {
    // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
    var abs = channel.abs();
    return abs >= 1 / 512
        ? channel.sign * math.pow(abs, 1 / 1.8)
        : 16 * channel;
  }

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.srgbLinear ||
        ColorSpace.srgb ||
        ColorSpace.rgb =>
          linearProphotoRgbToLinearSrgb,
        ColorSpace.a98Rgb => linearProphotoRgbToLinearA98Rgb,
        ColorSpace.displayP3 => linearProphotoRgbToLinearDisplayP3,
        ColorSpace.rec2020 => linearProphotoRgbToLinearRec2020,
        ColorSpace.xyzD65 => linearProphotoRgbToXyzD65,
        ColorSpace.xyzD50 => linearProphotoRgbToXyzD50,
        ColorSpace.lms => linearProphotoRgbToLms,
        _ => super.transformationMatrix(dest)
      };
}
