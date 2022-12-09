// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../conversions.dart';
import '../space.dart';
import 'utils.dart';

/// A constant used in the rec2020 gamma encoding/decoding functions.
const _alpha = 1.09929682680944;

/// A constant used in the rec2020 gamma encoding/decoding functions.
const _beta = 0.018053968510807;

/// The rec2020 color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-rec2020
///
/// @nodoc
@internal
class Rec2020ColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const Rec2020ColorSpace() : super('rec2020', rgbChannels);

  @protected
  double toLinear(double channel) {
    // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
    var abs = channel.abs();
    return abs < _beta * 4.5
        ? channel / 4.5
        : channel.sign * (math.pow((abs + _alpha - 1) / _alpha, 1 / 0.45));
  }

  @protected
  double fromLinear(double channel) {
    // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
    var abs = channel.abs();
    return abs > _beta
        ? channel.sign * (_alpha * math.pow(abs, 0.45) - (_alpha - 1))
        : 4.5 * channel;
  }

  @protected
  Float64List transformationMatrix(ColorSpace dest) {
    switch (dest) {
      case ColorSpace.srgbLinear:
      case ColorSpace.srgb:
      case ColorSpace.rgb:
        return linearRec2020ToLinearSrgb;
      case ColorSpace.a98Rgb:
        return linearRec2020ToLinearA98Rgb;
      case ColorSpace.displayP3:
        return linearRec2020ToLinearDisplayP3;
      case ColorSpace.prophotoRgb:
        return linearRec2020ToLinearProphotoRgb;
      case ColorSpace.xyzD65:
        return linearRec2020ToXyzD65;
      case ColorSpace.xyzD50:
        return linearRec2020ToXyzD50;
      case ColorSpace.lms:
        return linearRec2020ToLms;
      default:
        return super.transformationMatrix(dest);
    }
  }
}
