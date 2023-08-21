// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The xyz-d50 color space.
///
/// https://www.w3.org/TR/css-color-4/#predefined-xyz
///
/// @nodoc
@internal
class XyzD50ColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const XyzD50ColorSpace() : super('xyz-d50', xyzChannels);

  SassColor convert(
      ColorSpace dest, double x, double y, double z, double alpha) {
    switch (dest) {
      case ColorSpace.lab || ColorSpace.lch:
        // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
        // and http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
        var f0 = _convertComponentToLabF(x / d50[0]);
        var f1 = _convertComponentToLabF(y / d50[1]);
        var f2 = _convertComponentToLabF(z / d50[2]);

        return ColorSpace.lab.convert(
            dest, (116 * f1) - 16, 500 * (f0 - f1), 200 * (f1 - f2), alpha);

      default:
        return super.convert(dest, x, y, z, alpha);
    }
  }

  /// Does a partial conversion of a single XYZ component to Lab.
  double _convertComponentToLabF(double component) => component > labEpsilon
      ? math.pow(component, 1 / 3) + 0.0
      : (labKappa * component + 16) / 116;

  @protected
  double toLinear(double channel) => channel;

  @protected
  double fromLinear(double channel) => channel;

  @protected
  Float64List transformationMatrix(ColorSpace dest) => switch (dest) {
        ColorSpace.srgbLinear ||
        ColorSpace.srgb ||
        ColorSpace.rgb =>
          xyzD50ToLinearSrgb,
        ColorSpace.a98Rgb => xyzD50ToLinearA98Rgb,
        ColorSpace.prophotoRgb => xyzD50ToLinearProphotoRgb,
        ColorSpace.displayP3 => xyzD50ToLinearDisplayP3,
        ColorSpace.rec2020 => xyzD50ToLinearRec2020,
        ColorSpace.xyzD65 => xyzD50ToXyzD65,
        ColorSpace.lms => xyzD50ToLms,
        _ => super.transformationMatrix(dest)
      };
}
