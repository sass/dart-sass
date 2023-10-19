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

/// A color space whose channel names and semantics Sass knows.
///
/// {@category Value}
@sealed
abstract base class ColorSpace {
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
  /// https://www.w3.org/TR/css-color-4/#predefined-xyz
  static const ColorSpace xyzD65 = XyzD65ColorSpace();

  /// The xyz-d50 color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#predefined-xyz
  static const ColorSpace xyzD50 = XyzD50ColorSpace();

  /// The CIE Lab color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#cie-lab
  static const ColorSpace lab = LabColorSpace();

  /// The CIE LCH color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#cie-lab
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

  /// The Oklab color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#ok-lab
  static const ColorSpace oklab = OklabColorSpace();

  /// The Oklch color space.
  ///
  /// https://www.w3.org/TR/css-color-4/#ok-lab
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
  static ColorSpace fromName(String name, [String? argumentName]) =>
      switch (name.toLowerCase()) {
        'rgb' => rgb,
        'hwb' => hwb,
        'hsl' => hsl,
        'srgb' => srgb,
        'srgb-linear' => srgbLinear,
        'display-p3' => displayP3,
        'a98-rgb' => a98Rgb,
        'prophoto-rgb' => prophotoRgb,
        'rec2020' => rec2020,
        'xyz' || 'xyz-d65' => xyzD65,
        'xyz-d50' => xyzD50,
        'lab' => lab,
        'lch' => lch,
        'oklab' => oklab,
        'oklch' => oklch,
        _ => throw SassScriptException(
            'Unknown color space "$name".', argumentName)
      };

  /// Converts a color with the given channels from this color space to [dest].
  ///
  /// By default, this uses this color space's [toLinear] and
  /// [transformationMatrix] as well as [dest]'s [fromLinear], and relies on
  /// individual color space conversions to do more than purely linear
  /// conversions.
  ///
  /// @nodoc
  @internal
  SassColor convert(ColorSpace dest, double? channel0, double? channel1,
          double? channel2, double? alpha) =>
      convertLinear(dest, channel0, channel1, channel2, alpha);

  /// The default implementation of [convert], which always starts with a linear
  /// transformation from RGB or XYZ channels to a linear destination space,
  /// which may then further convert to a polar space.
  ///
  /// @nodoc
  @internal
  @protected
  @nonVirtual
  SassColor convertLinear(
      ColorSpace dest, double? red, double? green, double? blue, double? alpha,
      {bool missingLightness = false,
      bool missingChroma = false,
      bool missingHue = false,
      bool missingA = false,
      bool missingB = false}) {
    var linearDest = switch (dest) {
      ColorSpace.hsl || ColorSpace.hwb => const SrgbColorSpace(),
      ColorSpace.lab || ColorSpace.lch => const XyzD50ColorSpace(),
      ColorSpace.oklab || ColorSpace.oklch => const LmsColorSpace(),
      _ => dest
    };

    double? transformedRed;
    double? transformedGreen;
    double? transformedBlue;
    if (linearDest == this) {
      transformedRed = red;
      transformedGreen = green;
      transformedBlue = blue;
    } else {
      var linearRed = toLinear(red ?? 0);
      var linearGreen = toLinear(green ?? 0);
      var linearBlue = toLinear(blue ?? 0);
      var matrix = transformationMatrix(linearDest);

      // (matrix * [linearRed, linearGreen, linearBlue]).map(linearDest.fromLinear)
      transformedRed = linearDest.fromLinear(matrix[0] * linearRed +
          matrix[1] * linearGreen +
          matrix[2] * linearBlue);
      transformedGreen = linearDest.fromLinear(matrix[3] * linearRed +
          matrix[4] * linearGreen +
          matrix[5] * linearBlue);
      transformedBlue = linearDest.fromLinear(matrix[6] * linearRed +
          matrix[7] * linearGreen +
          matrix[8] * linearBlue);
    }

    return switch (dest) {
      ColorSpace.hsl || ColorSpace.hwb => const SrgbColorSpace().convert(
          dest, transformedRed, transformedGreen, transformedBlue, alpha,
          missingLightness: missingLightness,
          missingChroma: missingChroma,
          missingHue: missingHue),
      ColorSpace.lab || ColorSpace.lch => const XyzD50ColorSpace().convert(
          dest, transformedRed, transformedGreen, transformedBlue, alpha,
          missingLightness: missingLightness,
          missingChroma: missingChroma,
          missingHue: missingHue,
          missingA: missingA,
          missingB: missingB),
      ColorSpace.oklab || ColorSpace.oklch => const LmsColorSpace().convert(
          dest, transformedRed, transformedGreen, transformedBlue, alpha,
          missingLightness: missingLightness,
          missingChroma: missingChroma,
          missingHue: missingHue,
          missingA: missingA,
          missingB: missingB),
      _ => SassColor.forSpaceInternal(
          dest,
          red == null ? null : transformedRed,
          green == null ? null : transformedGreen,
          blue == null ? null : transformedBlue,
          alpha)
    };
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
