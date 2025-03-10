// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../exception.dart';
import '../../value.dart';

/// The method by which two colors are interpolated to find a color in the
/// middle.
///
/// Used by [SassColor.interpolate].
///
/// {@category Value}
class InterpolationMethod {
  /// The color space in which to perform the interpolation.
  final ColorSpace space;

  /// How to interpolate the hues between two colors.
  ///
  /// This is non-null if and only if [space] is a color space.
  final HueInterpolationMethod? hue;

  InterpolationMethod(this.space, [HueInterpolationMethod? hue])
      : hue = space.isPolar ? hue ?? HueInterpolationMethod.shorter : null {
    if (!space.isPolar && hue != null) {
      throw ArgumentError(
        "Hue interpolation method may not be set for rectangular color space "
        "$space.",
      );
    }
  }

  /// Parses a SassScript value representing an interpolation method, not
  /// beginning with "in".
  ///
  /// Throws a [SassScriptException] if [value] isn't a valid interpolation
  /// method. If [value] came from a function argument, [name] is the argument name
  /// (without the `$`). This is used for error reporting.
  factory InterpolationMethod.fromValue(Value value, [String? name]) {
    var list = value.assertCommonListStyle(name, allowSlash: false);
    if (list.isEmpty) {
      throw SassScriptException(
        'Expected a color interpolation method, got an empty list.',
        name,
      );
    }

    var space = ColorSpace.fromName(
      (list.first.assertString(name)..assertUnquoted(name)).text,
      name,
    );
    if (list.length == 1) return InterpolationMethod(space);

    var hueMethod = HueInterpolationMethod._fromValue(list[1], name);
    if (list.length == 2) {
      throw SassScriptException(
        'Expected unquoted string "hue" after $value.',
        name,
      );
    } else if ((list[2].assertString(name)..assertUnquoted(name))
            .text
            .toLowerCase() !=
        'hue') {
      throw SassScriptException(
        'Expected unquoted string "hue" at the end of $value, was ${list[2]}.',
        name,
      );
    } else if (list.length > 3) {
      throw SassScriptException(
        'Expected nothing after "hue" in $value.',
        name,
      );
    } else if (!space.isPolar) {
      throw SassScriptException(
        'Hue interpolation method "$hueMethod hue" may not be set for '
        'rectangular color space $space.',
        name,
      );
    }

    return InterpolationMethod(space, hueMethod);
  }

  String toString() => space.toString() + (hue == null ? '' : ' $hue hue');
}

/// The method by which two hues are adjusted when interpolating between colors.
///
/// Used by [InterpolationMethod].
///
/// {@category Value}
enum HueInterpolationMethod {
  /// Angles are adjusted so that `θ₂ - θ₁ ∈ [-180, 180]`.
  ///
  /// https://www.w3.org/TR/css-color-4/#shorter
  shorter,

  /// Angles are adjusted so that `θ₂ - θ₁ ∈ {0, [180, 360)}`.
  ///
  /// https://www.w3.org/TR/css-color-4/#hue-longer
  longer,

  /// Angles are adjusted so that `θ₂ - θ₁ ∈ [0, 360)`.
  ///
  /// https://www.w3.org/TR/css-color-4/#hue-increasing
  increasing,

  /// Angles are adjusted so that `θ₂ - θ₁ ∈ (-360, 0]`.
  ///
  /// https://www.w3.org/TR/css-color-4/#hue-decreasing
  decreasing;

  /// Parses a SassScript value representing a hue interpolation method, not
  /// ending with "hue".
  ///
  /// Throws a [SassScriptException] if [value] isn't a valid hue interpolation
  /// method. If [value] came from a function argument, [name] is the argument
  /// name (without the `$`). This is used for error reporting.
  factory HueInterpolationMethod._fromValue(Value value, [String? name]) =>
      switch ((value.assertString(name)..assertUnquoted()).text.toLowerCase()) {
        'shorter' => HueInterpolationMethod.shorter,
        'longer' => HueInterpolationMethod.longer,
        'increasing' => HueInterpolationMethod.increasing,
        'decreasing' => HueInterpolationMethod.decreasing,
        _ => throw SassScriptException(
            'Unknown hue interpolation method $value.',
            name,
          ),
      };
}
