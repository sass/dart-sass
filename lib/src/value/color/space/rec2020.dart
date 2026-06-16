// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../conversions.dart';
import '../space.dart';
import 'utils.dart';

/// The rec2020 color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-rec2020
///
/// @nodoc
@internal
final class Rec2020ColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const Rec2020ColorSpace() : super('rec2020', rgbChannels);

  @protected
  double toLinear(double channel) {
    // Non-linear transfer function from Rec. ITU-R BT.2020-2 table 4
    //  Reference electro-optical transfer function from Rec. ITU-R BT.1886 Annex 1
    //  with b (black lift) = 0 and a (user gain) = 1
    //  defined over the extended range, not clamped
    var abs = channel.abs();
    return channel.sign * math.pow(abs, 2.40);
  }

  @protected
  double fromLinear(double channel) {
    var abs = channel.abs();
    return channel.sign * math.pow(abs, 1 / 2.40);
  }

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.srgbLinear ||
        ColorSpace.srgb ||
        ColorSpace.rgb =>
          linearRec2020ToLinearSrgb,
        ColorSpace.a98Rgb => linearRec2020ToLinearA98Rgb,
        ColorSpace.displayP3 ||
        ColorSpace.displayP3Linear =>
          linearRec2020ToLinearDisplayP3,
        ColorSpace.prophotoRgb => linearRec2020ToLinearProphotoRgb,
        ColorSpace.xyzD65 => linearRec2020ToXyzD65,
        ColorSpace.xyzD50 => linearRec2020ToXyzD50,
        ColorSpace.lms => linearRec2020ToLms,
        _ => super.transformationMatrix(dest),
      };
}
