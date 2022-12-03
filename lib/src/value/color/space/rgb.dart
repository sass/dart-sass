// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'package:meta/meta.dart';

import '../../color.dart';
import 'utils.dart';

/// The legacy RGB color space.
///
/// @nodoc
@internal
class RgbColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;
  bool get isLegacyInternal => true;

  const RgbColorSpace()
      : super('rgb', const [
          LinearChannel('red', 0, 255),
          LinearChannel('green', 0, 255),
          LinearChannel('blue', 0, 255)
        ]);

  SassColor convert(ColorSpace dest, double red, double green, double blue,
          double alpha) =>
      ColorSpace.srgb.convert(dest, red / 255, green / 255, blue / 255, alpha);

  @protected
  double toLinear(double channel) => srgbAndDisplayP3ToLinear(channel / 255);

  @protected
  double fromLinear(double channel) =>
      srgbAndDisplayP3FromLinear(channel) * 255;
}
