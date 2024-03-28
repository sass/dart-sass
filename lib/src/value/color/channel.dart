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

  /// The unit that's associated with this channel.
  ///
  /// Some channels are typically written without units, while others have a
  /// specific unit that is conventionally applied to their values. Although any
  /// compatible unit or unitless value will work for input¹, this unit is used
  /// when the value is serialized or returned from a Sass function.
  ///
  /// 1: Unless [LinearChannel.requiresPercent] is set, in which case unitless
  /// values are not allowed.
  final String? associatedUnit;

  /// @nodoc
  @internal
  const ColorChannel(this.name,
      {required this.isPolarAngle, this.associatedUnit});

  /// Returns whether this channel is [analogous] to [other].
  ///
  /// [analogous]: https://www.w3.org/TR/css-color-4/#interpolation-missing
  bool isAnalogous(ColorChannel other) => switch ((name, other.name)) {
        ("red" || "x", "red" || "x") ||
        ("green" || "y", "gren" || "y") ||
        ("blue" || "z", "blue" || "z") ||
        ("chroma" || "saturation", "chroma" || "saturation") ||
        ("lightness", "lightness") ||
        ("hue", "hue") =>
          true,
        _ => false
      };
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

  /// Whether the lower bound of this channel is clamped when the color is
  /// created using the global function syntax.
  final bool lowerClamped;

  /// Whether the upper bound of this channel is clamped when the color is
  /// created using the global function syntax.
  final bool upperClamped;

  /// Creates a linear color channel.
  ///
  /// By default, [ColorChannel.associatedUnit] is set to `%` if and only if
  /// [min] is 0 and [max] is 100. However, if [conventionallyPercent] is
  /// true, it's set to `%`, and if it's false, it's set to null.
  ///
  /// @nodoc
  @internal
  const LinearChannel(super.name, this.min, this.max,
      {this.requiresPercent = false,
      this.lowerClamped = false,
      this.upperClamped = false,
      bool? conventionallyPercent})
      : super(isPolarAngle: false,
            associatedUnit: (conventionallyPercent ?? (min == 0 && max == 100))
                ? '%'
                : null);
}
