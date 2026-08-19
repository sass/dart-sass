// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../util/nullable.dart';
import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The display-p3 color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-display-p3
///
/// @nodoc
@internal
final class const DisplayP3ColorSpace() extends ColorSpace {
  @override
  bool get isBoundedInternal => true;

  this : super('display-p3', rgbChannels);

  @override
  SassColor convert(
    ColorSpace dest,
    double? red,
    double? green,
    double? blue,
    double? alpha,
  ) => dest == .displayP3Linear
      ? SassColor.forSpaceInternal(
          dest,
          red.andThen(toLinear),
          green.andThen(toLinear),
          blue.andThen(toLinear),
          alpha,
        )
      : super.convertLinear(dest, red, green, blue, alpha);

  @override
  @protected
  double toLinear(double channel) => srgbAndDisplayP3ToLinear(channel);

  @override
  @protected
  double fromLinear(double channel) => srgbAndDisplayP3FromLinear(channel);

  @override
  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
    .srgbLinear || .srgb || .rgb => linearDisplayP3ToLinearSrgb,
    .a98Rgb => linearDisplayP3ToLinearA98Rgb,
    .prophotoRgb => linearDisplayP3ToLinearProphotoRgb,
    .rec2020 => linearDisplayP3ToLinearRec2020,
    .xyzD65 => linearDisplayP3ToXyzD65,
    .xyzD50 => linearDisplayP3ToXyzD50,
    .lms => linearDisplayP3ToLms,
    _ => super.transformationMatrix(dest),
  };
}
