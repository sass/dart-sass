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
final class DisplayP3ColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const DisplayP3ColorSpace() : super('display-p3', rgbChannels);

  @protected
  double toLinear(double channel) => srgbAndDisplayP3ToLinear(channel);

  @protected
  double fromLinear(double channel) => srgbAndDisplayP3FromLinear(channel);

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.srgbLinear ||
        ColorSpace.srgb ||
        ColorSpace.rgb =>
          linearDisplayP3ToLinearSrgb,
        ColorSpace.a98Rgb => linearDisplayP3ToLinearA98Rgb,
        ColorSpace.prophotoRgb => linearDisplayP3ToLinearProphotoRgb,
        ColorSpace.rec2020 => linearDisplayP3ToLinearRec2020,
        ColorSpace.xyzD65 => linearDisplayP3ToXyzD65,
        ColorSpace.xyzD50 => linearDisplayP3ToXyzD50,
        ColorSpace.lms => linearDisplayP3ToLms,
        _ => super.transformationMatrix(dest)
      };
}
