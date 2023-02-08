// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'package:meta/meta.dart';

import '../../color.dart';
import 'utils.dart';

/// The legacy HWB color space.
///
/// @nodoc
@internal
class HwbColorSpace extends ColorSpace {
  bool get isBoundedInternal => true;
  bool get isStrictlyBoundedInternal => true;
  bool get isLegacyInternal => true;
  bool get isPolarInternal => true;

  const HwbColorSpace()
      : super('hwb', const [
          hueChannel,
          LinearChannel('whiteness', 0, 100, requiresPercent: true),
          LinearChannel('blackness', 0, 100, requiresPercent: true)
        ]);

  SassColor convert(ColorSpace dest, double? hue, double? whiteness,
      double? blackness, double alpha) {
    // From https://www.w3.org/TR/css-color-4/#hwb-to-rgb
    var scaledHue = (hue ?? 0) % 360 / 360;
    var scaledWhiteness = (whiteness ?? 0) / 100;
    var scaledBlackness = (blackness ?? 0) / 100;

    var sum = scaledWhiteness + scaledBlackness;
    if (sum > 1) {
      scaledWhiteness /= sum;
      scaledBlackness /= sum;
    }

    var factor = 1 - scaledWhiteness - scaledBlackness;
    double toRgb(double hue) => hueToRgb(0, 1, hue) * factor + scaledWhiteness;

    return forwardMissingChannels(
        ColorSpace.srgb.convert(dest, toRgb(scaledHue + 1 / 3),
            toRgb(scaledHue), toRgb(scaledHue - 1 / 3), alpha),
        missingHue: hue == null);
  }
}
