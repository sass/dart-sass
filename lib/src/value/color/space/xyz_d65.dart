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
final class XyzD65ColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const XyzD65ColorSpace() : super('xyz', xyzChannels);

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.srgbLinear ||
        ColorSpace.srgb ||
        ColorSpace.rgb =>
          xyzD65ToLinearSrgb,
        ColorSpace.a98Rgb => xyzD65ToLinearA98Rgb,
        ColorSpace.prophotoRgb => xyzD65ToLinearProphotoRgb,
        ColorSpace.displayP3 => xyzD65ToLinearDisplayP3,
        ColorSpace.rec2020 => xyzD65ToLinearRec2020,
        ColorSpace.xyzD50 => xyzD65ToXyzD50,
        ColorSpace.lms => xyzD65ToLms,
        _ => super.transformationMatrix(dest)
      };
}
