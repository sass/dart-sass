// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

/// Metadata about a single channel in a known color space.
///
/// {@category Value}
@sealed
class ColorChannel {
  /// The alpha channel that's shared across all colors.
  static const alpha = LinearChannel('alpha', 0, 1);

  /// The channel's name.
  final String name;

  /// Whether this is a polar angle channel, which represents (in degrees) the
  /// angle around a circle.
  ///
  /// This is true if and only if this is not a [LinearChannel].
  final bool isPolarAngle;

  /// @nodoc
  @internal
  const ColorChannel(this.name, {required this.isPolarAngle});

  /// Returns whether this channel is [analogous] to [other].
  ///
  /// [analogous]: https://www.w3.org/TR/css-color-4/#interpolation-missing
  bool isAnalogous(ColorChannel other) {
    switch (name) {
      case "red":
      case "x":
        return other.name == "red" || other.name == "x";

      case "green":
      case "y":
        return other.name == "green" || other.name == "y";

      case "blue":
      case "z":
        return other.name == "blue" || other.name == "z";

      case "chroma":
      case "saturation":
        return other.name == "chroma" || other.name == "saturation";

      case "lightness":
      case "hue":
        return other.name == name;

      default:
        return false;
    }
  }
}

/// Metadata about a color channel with a linear (as opposed to polar) value.
///
/// {@category Value}
@sealed
class LinearChannel extends ColorChannel {
  /// The channel's minimum value.
  ///
  /// Unless this color space is strictly bounded, this channel's values may
  /// still be below this minimum value. It just represents a limit to reference
  /// when specifying channels by percentage, as well as a boundary for what's
  /// considered in-gamut if the color space has a bounded gamut.
  final double min;

  /// The channel's maximum value.
  ///
  /// Unless this color space is strictly bounded, this channel's values may
  /// still be above this maximum value. It just represents a limit to reference
  /// when specifying channels by percentage, as well as a boundary for what's
  /// considered in-gamut if the color space has a bounded gamut.
  final double max;

  /// Whether this channel requires values to be specified with unit `%` and
  /// forbids unitless values.
  final bool requiresPercent;

  /// @nodoc
  @internal
  const LinearChannel(String name, this.min, this.max,
      {this.requiresPercent = false})
      : super(name, isPolarAngle: false);
}
