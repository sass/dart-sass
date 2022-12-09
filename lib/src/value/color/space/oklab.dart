// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The OKLab color space.
///
/// https://www.w3.org/TR/css-color-4/#specifying-oklab-oklch
///
/// @nodoc
@internal
class OklabColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const OklabColorSpace()
      : super('oklab', const [
          LinearChannel('lightness', 0, 1),
          LinearChannel('a', -0.4, 0.4),
          LinearChannel('b', -0.4, 0.4)
        ]);

  SassColor convert(
      ColorSpace dest, double lightness, double a, double b, double alpha) {
    if (dest == ColorSpace.oklch) {
      return labToLch(dest, lightness, a, b, alpha);
    }

    // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
    return ColorSpace.lms.convert(
        dest,
        math.pow(
                oklabToLms[0] * lightness +
                    oklabToLms[1] * a +
                    oklabToLms[2] * b,
                3) +
            0.0,
        math.pow(
                oklabToLms[3] * lightness +
                    oklabToLms[4] * a +
                    oklabToLms[5] * b,
                3) +
            0.0,
        math.pow(
                oklabToLms[6] * lightness +
                    oklabToLms[7] * a +
                    oklabToLms[8] * b,
                3) +
            0.0,
        alpha);
  }
}
