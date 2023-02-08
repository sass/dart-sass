// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../util/number.dart';
import '../../color.dart';
import '../conversions.dart';
import 'utils.dart';

/// The Lab color space.
///
/// https://www.w3.org/TR/css-color-4/#specifying-lab-lch
///
/// @nodoc
@internal
class LabColorSpace extends ColorSpace {
  bool get isBoundedInternal => false;

  const LabColorSpace()
      : super('lab', const [
          LinearChannel('lightness', 0, 100),
          LinearChannel('a', -125, 125),
          LinearChannel('b', -125, 125)
        ]);

  SassColor convert(
      ColorSpace dest, double? lightness, double? a, double? b, double alpha) {
    switch (dest) {
      case ColorSpace.lab:
        var powerlessAB = lightness == null || fuzzyEquals(lightness, 0);
        return SassColor.lab(
            lightness, powerlessAB ? null : a, powerlessAB ? null : b, alpha);

      case ColorSpace.lch:
        return labToLch(dest, lightness, a, b, alpha);

      default:
        // Algorithm from https://www.w3.org/TR/css-color-4/#color-conversion-code
        // and http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
        var lightnessOr0 = lightness ?? 0;
        var f1 = (lightnessOr0 + 16) / 116;

        return forwardMissingChannels(
            ColorSpace.xyzD50.convert(
                dest,
                _convertFToXorZ((a??0) / 500 + f1) * d50[0],
                (lightnessOr0 > labKappa * labEpsilon
                        ? math.pow(f1, 3) * 1.0
                        : lightnessOr0 / labKappa) *
                    d50[1],
                _convertFToXorZ(f1 - (b??0) / 200) * d50[2],
                alpha),
            missingLightness: lightness == null);
    }
  }

  /// Converts an f-format component to the X or Z channel of an XYZ color.
  double _convertFToXorZ(double component) {
    var cubed = math.pow(component, 3) + 0.0;
    return cubed > labEpsilon ? cubed : (116 * component - 16) / labKappa;
  }
}
