// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../color.dart';
import 'oklab.dart';
import 'utils.dart';

/// The OKLCH color space.
///
/// https://www.w3.org/TR/css-color-4/#specifying-oklab-oklch
///
/// @nodoc
@internal
final class OklchColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;
  bool get isPolarInternal => true;

  const OklchColorSpace()
      : super('oklch', const [
          LinearChannel('lightness', 0, 1,
              conventionallyPercent: true,
              lowerClamped: true,
              upperClamped: true),
          LinearChannel('chroma', 0, 0.4, lowerClamped: true),
          hueChannel
        ]);

  SassColor convert(ColorSpace dest, double? lightness, double? chroma,
      double? hue, double? alpha) {
    var hueRadians = (hue ?? 0) * math.pi / 180;
    return const OklabColorSpace().convert(
        dest,
        lightness,
        (chroma ?? 0) * math.cos(hueRadians),
        (chroma ?? 0) * math.sin(hueRadians),
        alpha,
        missingChroma: chroma == null,
        missingHue: hue == null);
  }
}
