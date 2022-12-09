// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../conversions.dart';
import '../space.dart';
import 'utils.dart';

/// The xyz-d65 color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-xyz
///
/// @nodoc
@internal
class XyzD65ColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const XyzD65ColorSpace() : super('xyz', xyzChannels);

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
        return xyzD65ToLinearSrgb;
      case ColorSpace.a98Rgb:
        return xyzD65ToLinearA98Rgb;
      case ColorSpace.prophotoRgb:
        return xyzD65ToLinearProphotoRgb;
      case ColorSpace.displayP3:
        return xyzD65ToLinearDisplayP3;
      case ColorSpace.rec2020:
        return xyzD65ToLinearRec2020;
      case ColorSpace.xyzD50:
        return xyzD65ToXyzD50;
      case ColorSpace.lms:
        return xyzD65ToLms;
      default:
        return super.transformationMatrix(dest);
    }
  }
}
