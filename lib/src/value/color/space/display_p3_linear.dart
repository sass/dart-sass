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
final class const DisplayP3LinearColorSpace() extends ColorSpace {
  @override
  bool get isBoundedInternal => true;

  this : super('display-p3-linear', rgbChannels);

  @override
  SassColor convert(
    ColorSpace dest,
    double? red,
    double? green,
    double? blue,
    double? alpha,
  ) => dest == .displayP3
      ? SassColor.forSpaceInternal(
          dest,
          red.andThen(srgbAndDisplayP3FromLinear),
          green.andThen(srgbAndDisplayP3FromLinear),
          blue.andThen(srgbAndDisplayP3FromLinear),
          alpha,
        )
      : super.convert(dest, red, green, blue, alpha);

  @override
  @protected
  double toLinear(double channel) => channel;

  @override
  @protected
  double fromLinear(double channel) => channel;

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
