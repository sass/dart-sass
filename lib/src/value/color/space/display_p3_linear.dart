// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../util/nullable.dart';
import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The display-p3-linear color space.
///
/// https://drafts.csswg.org/css-color/#predefined-display-p3-linear
///
/// @nodoc
@internal
final class DisplayP3LinearColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;

  const DisplayP3LinearColorSpace() : super('display-p3-linear', rgbChannels);

  SassColor convert(
    ColorSpace dest,
    double? red,
    double? green,
    double? blue,
    double? alpha,
  ) =>
      dest == ColorSpace.displayP3
          ? SassColor.forSpaceInternal(
              dest,
              red.andThen(srgbAndDisplayP3FromLinear),
              green.andThen(srgbAndDisplayP3FromLinear),
              blue.andThen(srgbAndDisplayP3FromLinear),
              alpha,
            )
          : super.convert(dest, red, green, blue, alpha);

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

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
        _ => super.transformationMatrix(dest),
      };
}
