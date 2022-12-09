// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../conversions.dart';
import '../space.dart';
import 'utils.dart';

/// The display-p3 color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-display-p3
///
/// @nodoc
@internal
class DisplayP3ColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const DisplayP3ColorSpace() : super('display-p3', rgbChannels);

  @protected
  double toLinear(double channel) => srgbAndDisplayP3ToLinear(channel);

  @protected
  double fromLinear(double channel) => srgbAndDisplayP3FromLinear(channel);

  @protected
  Float64List transformationMatrix(ColorSpace dest) {
    switch (dest) {
      case ColorSpace.srgbLinear:
      case ColorSpace.srgb:
      case ColorSpace.rgb:
        return linearDisplayP3ToLinearSrgb;
      case ColorSpace.a98Rgb:
        return linearDisplayP3ToLinearA98Rgb;
      case ColorSpace.prophotoRgb:
        return linearDisplayP3ToLinearProphotoRgb;
      case ColorSpace.rec2020:
        return linearDisplayP3ToLinearRec2020;
      case ColorSpace.xyzD65:
        return linearDisplayP3ToXyzD65;
      case ColorSpace.xyzD50:
        return linearDisplayP3ToXyzD50;
      case ColorSpace.lms:
        return linearDisplayP3ToLms;
      default:
        return super.transformationMatrix(dest);
    }
  }
}
