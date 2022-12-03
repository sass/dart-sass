// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../exception.dart';
import '../color.dart';
import 'space/a98_rgb.dart';
import 'space/display_p3.dart';
import 'space/hsl.dart';
import 'space/hwb.dart';
import 'space/lab.dart';
import 'space/lch.dart';
import 'space/lms.dart';
import 'space/oklab.dart';
import 'space/oklch.dart';
import 'space/prophoto_rgb.dart';
import 'space/rec2020.dart';
import 'space/rgb.dart';
import 'space/srgb.dart';
import 'space/srgb_linear.dart';
import 'space/xyz_d50.dart';
import 'space/xyz_d65.dart';

// TODO: limit instance methods to sass_api

/// A color space whose channel names and semantics Sass knows.
///
/// {@category Value}
@sealed
abstract class ColorSpace {
  /// The legacy RGB color space.
  static const ColorSpace rgb = RgbColorSpace();

  /// The legacy HSL color space.
  static const ColorSpace hsl = HslColorSpace();

  /// The legacy HWB color space.
  static const ColorSpace hwb = HwbColorSpace();

  /// The sRGB color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-sRGB
  static const ColorSpace srgb = SrgbColorSpace();

  /// The linear-light sRGB color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-sRGB-linear
  static const ColorSpace srgbLinear = SrgbLinearColorSpace();

  /// The display-p3 color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-display-p3
  static const ColorSpace displayP3 = DisplayP3ColorSpace();

  /// The a98-rgb color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-a98-rgb
  static const ColorSpace a98Rgb = A98RgbColorSpace();

  /// The prophoto-rgb color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-prophoto-rgb
  static const ColorSpace prophotoRgb = ProphotoRgbColorSpace();

  /// The rec2020 color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-rec2020
  static const ColorSpace rec2020 = Rec2020ColorSpace();

  /// The xyz-d65 color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-xyz-d65
  static const ColorSpace xyzD65 = XyzD65ColorSpace();

  /// The xyz-d50 color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-xyz-d50
  static const ColorSpace xyzD50 = XyzD50ColorSpace();

  static const ColorSpace lab = LabColorSpace();

  static const ColorSpace lch = LchColorSpace();

  /// The internal LMS color space.
  ///
  /// This only used as an intermediate space for conversions to and from OKLab
  /// and OKLCH. It's never used in a real color value and isn't returned by
  /// [fromName].
  ///
  /// @nodoc
  @internal
  static const ColorSpace lms = LmsColorSpace();

  static const ColorSpace oklab = OklabColorSpace();

  static const ColorSpace oklch = OklchColorSpace();

  /// The CSS name of the color space.
  final String name;

  /// See [SassApiColorSpace.channels].
  final List<ColorChannel> _channels;

  /// See [SassApiColorSpace.isBounded].
  ///
  /// @nodoc
  @internal
  bool get isBoundedInternal;

  /// See [SassApiColorSpace.isStrictlyBounded].
  ///
  /// @nodoc
  @internal
  bool get isStrictlyBoundedInternal => false;

  /// See [SassApiColorSpace.isLegacy].
  ///
  /// @nodoc
  @internal
  bool get isLegacyInternal => false;

  /// See [SassApiColorSpace.isPolar].
  ///
  /// @nodoc
  @internal
  bool get isPolarInternal => false;

  /// @nodoc
  @internal
  const ColorSpace(this.name, this._channels);

  /// Given a color space name, returns the known color space with that name or
  /// throws a [SassScriptException] if there is none.
  ///
  /// If this came from a function argument, [argumentName] is the argument name
  /// (without the `$`). This is used for error reporting.
  static ColorSpace fromName(String name, [String? argumentName]) {
    switch (name.toLowerCase()) {
      case 'rgb':
        return rgb;
      case 'hwb':
        return hwb;
      case 'hsl':
        return hsl;
      case 'srgb':
        return srgb;
      case 'srgb-linear':
        return srgbLinear;
      case 'display-p3':
        return displayP3;
      case 'a98-rgb':
        return a98Rgb;
      case 'prophoto-rgb':
        return prophotoRgb;
      case 'rec2020':
        return rec2020;
      case 'xyz':
      case 'xyz-d65':
        return xyzD65;
      case 'xyz-d50':
        return xyzD50;
      case 'lab':
        return lab;
      case 'lch':
        return lch;
      case 'oklab':
        return oklab;
      case 'oklch':
        return oklch;
      default:
        throw SassScriptException('Unknown color space "$name".', argumentName);
    }
  }

  /// Converts a color with the given channels from this color space to [dest].
  ///
  /// By default, this uses this color space's [toLinear] and
  /// [transformationMatrix] as well as [dest]'s [fromLinear], and relies on
  /// individual color space conversions to do more than purely linear
  /// conversions.
  ///
  /// @nodoc
  @internal
  SassColor convert(ColorSpace dest, double channel0, double channel1,
      double channel2, double alpha) {
    var linearDest = dest;
    switch (dest) {
      case ColorSpace.hsl:
      case ColorSpace.hwb:
        linearDest = ColorSpace.srgb;
        break;

      case ColorSpace.lab:
      case ColorSpace.lch:
        linearDest = ColorSpace.xyzD50;
        break;

      case ColorSpace.oklab:
      case ColorSpace.oklch:
        linearDest = ColorSpace.lms;
        break;
    }

    double transformed0;
    double transformed1;
    double transformed2;
    if (linearDest == this) {
      transformed0 = channel0;
      transformed1 = channel1;
      transformed2 = channel2;
    } else {
      var linear0 = toLinear(channel0);
      var linear1 = toLinear(channel1);
      var linear2 = toLinear(channel2);
      var matrix = transformationMatrix(linearDest);

      // (matrix * [linear0, linear1, linear2]).map(linearDest.fromLinear)
      transformed0 = linearDest.fromLinear(
          matrix[0] * linear0 + matrix[1] * linear1 + matrix[2] * linear2);
      transformed1 = linearDest.fromLinear(
          matrix[3] * linear0 + matrix[4] * linear1 + matrix[5] * linear2);
      transformed2 = linearDest.fromLinear(
          matrix[6] * linear0 + matrix[7] * linear1 + matrix[8] * linear2);
    }

    switch (dest) {
      case ColorSpace.hsl:
      case ColorSpace.hwb:
      case ColorSpace.lab:
      case ColorSpace.lch:
      case ColorSpace.oklab:
      case ColorSpace.oklch:
        return linearDest.convert(
            dest, transformed0, transformed1, transformed2, alpha);

      default:
        return SassColor.forSpaceInternal(
            dest, transformed0, transformed1, transformed2, alpha);
    }
  }

  /// Converts a channel in this color space into an element of a vector that
  /// can be linearly transformed into other color spaces.
  ///
  /// The precise semantics of this vector may vary from color space to color
  /// space. The only requirement is that, for any space `dest` for which
  /// `transformationMatrix(dest)` returns a value,
  /// `dest.fromLinear(toLinear(channels) * transformationMatrix(dest))`
  /// converts from this space to `dest`.
  ///
  /// If a color space explicitly supports all conversions in [convert], it need
  /// not override this at all.
  ///
  /// @nodoc
  @protected
  @internal
  double toLinear(double channel) => throw UnimplementedError(
      "[BUG] Color space $this doesn't support linear conversions.");

  /// Converts an element of a 3-element vector that can be linearly transformed
  /// into other color spaces into a channel in this color space.
  ///
  /// The precise semantics of this vector may vary from color space to color
  /// space. The only requirement is that, for any space `dest` for which
  /// `transformationMatrix(dest)` returns a value,
  /// `dest.fromLinear(toLinear(channels) * transformationMatrix(dest))`
  /// converts from this space to `dest`.
  ///
  /// If a color space explicitly supports all conversions in [convert], it need
  /// not override this at all.
  ///
  /// @nodoc
  @protected
  @internal
  double fromLinear(double channel) => throw UnimplementedError(
      "[BUG] Color space $this doesn't support linear conversions.");

  /// Returns the matrix for performing a linear transformation from this color
  /// space to [dest].
  ///
  /// Specifically, `dest.fromLinear(toLinear(channels) *
  /// transformationMatrix(dest))` must convert from this space to `dest`.
  ///
  /// This only needs to return values for color spaces that aren't explicitly
  /// supported in [convert]. If a color space explicitly supports all
  /// conversions in [convert], it need not override this at all.
  ///
  /// @nodoc
  @protected
  @internal
  Float64List transformationMatrix(ColorSpace dest) => throw UnimplementedError(
      '[BUG] Color space conversion from $this to $dest not implemented.');

  String toString() => name;
}

/// ColorSpace methods that are only visible through the `sass_api` package.
extension SassApiColorSpace on ColorSpace {
  // This color space's channels.
  List<ColorChannel> get channels => _channels;

  /// Whether this color space has a bounded gamut.
  bool get isBounded => isBoundedInternal;

  /// Whether this color space is _strictly_ bounded.
  ///
  /// If this is `true`, channel values outside of their bounds are meaningless
  /// and therefore forbidden, rather than being considered valid but
  /// out-of-gamut.
  ///
  /// This is only `true` if [isBounded] is also `true`.
  bool get isStrictlyBounded => isStrictlyBoundedInternal;

  /// Whether this is a legacy color space.
  bool get isLegacy => isLegacyInternal;

  /// Whether this color space uses a polar coordinate system.
  bool get isPolar => isPolarInternal;
}
