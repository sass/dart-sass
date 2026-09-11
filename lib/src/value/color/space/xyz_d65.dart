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
final class const XyzD65ColorSpace() extends ColorSpace {
  @override
  bool get isBoundedInternal => false;

  this : super('xyz', xyzChannels);

  @override
  @protected
  double toLinear(double channel) => channel;

  @override
  @protected
  double fromLinear(double channel) => channel;

  @override
  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
    .srgbLinear || .srgb || .rgb => xyzD65ToLinearSrgb,
    .a98Rgb => xyzD65ToLinearA98Rgb,
    .prophotoRgb => xyzD65ToLinearProphotoRgb,
    .displayP3 || .displayP3Linear => xyzD65ToLinearDisplayP3,
    .rec2020 => xyzD65ToLinearRec2020,
    .xyzD50 => xyzD65ToXyzD50,
    .lms => xyzD65ToLms,
    _ => super.transformationMatrix(dest),
  };
}
