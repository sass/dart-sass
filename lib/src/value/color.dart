// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../exception.dart';
import '../util/number.dart';
import '../value.dart';
import '../visitor/interface/value.dart';

/// A SassScript color.
///
/// {@category Value}
@sealed
class SassColor extends Value {
  /// This color's red channel, between `0` and `255`.
  int get red {
    if (_red == null) _hslToRgb();
    return _red!;
  }

  int? _red;

  /// This color's green channel, between `0` and `255`.
  int get green {
    if (_green == null) _hslToRgb();
    return _green!;
  }

  int? _green;

  /// This color's blue channel, between `0` and `255`.
  int get blue {
    if (_blue == null) _hslToRgb();
    return _blue!;
  }

  int? _blue;

  /// This color's hue, between `0` and `360`.
  num get hue {
    if (_hue == null) _rgbToHsl();
    return _hue!;
  }

  num? _hue;

  /// This color's saturation, a percentage between `0` and `100`.
  num get saturation {
    if (_saturation == null) _rgbToHsl();
    return _saturation!;
  }

  num? _saturation;

  /// This color's lightness, a percentage between `0` and `100`.
  num get lightness {
    if (_lightness == null) _rgbToHsl();
    return _lightness!;
  }

  num? _lightness;

  /// This color's whiteness, a percentage between `0` and `100`.
  num get whiteness {
    // Because HWB is (currently) used much less frequently than HSL or RGB, we
    // don't cache its values because we expect the memory overhead of doing so
    // to outweigh the cost of recalculating it on access.
    return math.min(math.min(red, green), blue) / 255 * 100;
  }

  /// This color's blackness, a percentage between `0` and `100`.
  num get blackness {
    // Because HWB is (currently) used much less frequently than HSL or RGB, we
    // don't cache its values because we expect the memory overhead of doing so
    // to outweigh the cost of recalculating it on access.
    return 100 - math.max(math.max(red, green), blue) / 255 * 100;
  }

  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

  /// This color's alpha channel, between `0` and `1`.
  num get alpha => _alpha;
  final num _alpha;

  /// The original string representation of this color, or `null` if one is
  /// unavailable.
  ///
  /// @nodoc
  @internal
  String? get original => originalSpan?.text;

  /// The span tracking the location in which this color was originally defined.
  ///
  /// This is tracked as a span to avoid extra substring allocations.
  ///
  /// @nodoc
  @internal
  final FileSpan? originalSpan;

  /// Creates an RGB color.
  ///
  /// Throws a [RangeError] if [red], [green], and [blue] aren't between `0` and
  /// `255`, or if [alpha] isn't between `0` and `1`.
  SassColor.rgb(this._red, this._green, this._blue,
      [num? alpha, this.originalSpan])
      : _alpha = alpha == null ? 1 : fuzzyAssertRange(alpha, 0, 1, "alpha") {
    RangeError.checkValueInInterval(red, 0, 255, "red");
    RangeError.checkValueInInterval(green, 0, 255, "green");
    RangeError.checkValueInInterval(blue, 0, 255, "blue");
  }

  /// Creates an HSL color.
  ///
  /// Throws a [RangeError] if [saturation] or [lightness] aren't between `0`
  /// and `100`, or if [alpha] isn't between `0` and `1`.
  SassColor.hsl(num hue, num saturation, num lightness, [num? alpha])
      : _hue = hue % 360,
        _saturation = fuzzyAssertRange(saturation, 0, 100, "saturation"),
        _lightness = fuzzyAssertRange(lightness, 0, 100, "lightness"),
        _alpha = alpha == null ? 1 : fuzzyAssertRange(alpha, 0, 1, "alpha"),
        originalSpan = null;

  /// Creates an HWB color.
  ///
  /// Throws a [RangeError] if [whiteness] or [blackness] aren't between `0` and
  /// `100`, or if [alpha] isn't between `0` and `1`.
  factory SassColor.hwb(num hue, num whiteness, num blackness, [num? alpha]) {
    // From https://www.w3.org/TR/css-color-4/#hwb-to-rgb
    var scaledHue = hue % 360 / 360;
    var scaledWhiteness =
        fuzzyAssertRange(whiteness, 0, 100, "whiteness") / 100;
    var scaledBlackness =
        fuzzyAssertRange(blackness, 0, 100, "blackness") / 100;

    var sum = scaledWhiteness + scaledBlackness;
    if (sum > 1) {
      scaledWhiteness /= sum;
      scaledBlackness /= sum;
    }

    var factor = 1 - scaledWhiteness - scaledBlackness;
    int toRgb(num hue) {
      var channel = _hueToRgb(0, 1, hue) * factor + scaledWhiteness;
      return fuzzyRound(channel * 255);
    }

    // Because HWB is (currently) used much less frequently than HSL or RGB, we
    // don't cache its values because we expect the memory overhead of doing so
    // to outweigh the cost of recalculating it on access. Instead, we eagerly
    // convert it to RGB and then convert back if necessary.
    return SassColor.rgb(toRgb(scaledHue + 1 / 3), toRgb(scaledHue),
        toRgb(scaledHue - 1 / 3), alpha);
  }

  SassColor._(this._red, this._green, this._blue, this._hue, this._saturation,
      this._lightness, this._alpha)
      : originalSpan = null;

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitColor(this);

  SassColor assertColor([String? name]) => this;

  /// Changes one or more of this color's RGB channels and returns the result.
  SassColor changeRgb({int? red, int? green, int? blue, num? alpha}) =>
      SassColor.rgb(red ?? this.red, green ?? this.green, blue ?? this.blue,
          alpha ?? this.alpha);

  /// Changes one or more of this color's HSL channels and returns the result.
  SassColor changeHsl(
          {num? hue, num? saturation, num? lightness, num? alpha}) =>
      SassColor.hsl(hue ?? this.hue, saturation ?? this.saturation,
          lightness ?? this.lightness, alpha ?? this.alpha);

  /// Changes one or more of this color's HWB channels and returns the result.
  SassColor changeHwb({num? hue, num? whiteness, num? blackness, num? alpha}) =>
      SassColor.hwb(hue ?? this.hue, whiteness ?? this.whiteness,
          blackness ?? this.blackness, alpha ?? this.alpha);

  /// Returns a new copy of this color with the alpha channel set to [alpha].
  SassColor changeAlpha(num alpha) => SassColor._(_red, _green, _blue, _hue,
      _saturation, _lightness, fuzzyAssertRange(alpha, 0, 1, "alpha"));

  /// @nodoc
  @internal
  Value plus(Value other) {
    if (other is! SassNumber && other is! SassColor) return super.plus(other);
    throw SassScriptException('Undefined operation "$this + $other".');
  }

  /// @nodoc
  @internal
  Value minus(Value other) {
    if (other is! SassNumber && other is! SassColor) return super.minus(other);
    throw SassScriptException('Undefined operation "$this - $other".');
  }

  /// @nodoc
  @internal
  Value dividedBy(Value other) {
    if (other is! SassNumber && other is! SassColor) {
      return super.dividedBy(other);
    }
    throw SassScriptException('Undefined operation "$this / $other".');
  }

  bool operator ==(Object other) =>
      other is SassColor &&
      other.red == red &&
      other.green == green &&
      other.blue == blue &&
      other.alpha == alpha;

  int get hashCode =>
      red.hashCode ^ green.hashCode ^ blue.hashCode ^ alpha.hashCode;

  /// Computes [_hue], [_saturation], and [_value] based on [red], [green], and
  /// [blue].
  void _rgbToHsl() {
    // Algorithm from https://en.wikipedia.org/wiki/HSL_and_HSV#RGB_to_HSL_and_HSV
    var scaledRed = red / 255;
    var scaledGreen = green / 255;
    var scaledBlue = blue / 255;

    var max = math.max(math.max(scaledRed, scaledGreen), scaledBlue);
    var min = math.min(math.min(scaledRed, scaledGreen), scaledBlue);
    var delta = max - min;

    if (max == min) {
      _hue = 0;
    } else if (max == scaledRed) {
      _hue = (60 * (scaledGreen - scaledBlue) / delta) % 360;
    } else if (max == scaledGreen) {
      _hue = (120 + 60 * (scaledBlue - scaledRed) / delta) % 360;
    } else if (max == scaledBlue) {
      _hue = (240 + 60 * (scaledRed - scaledGreen) / delta) % 360;
    }

    var lightness = _lightness = 50 * (max + min);

    if (max == min) {
      _saturation = 0;
    } else if (lightness < 50) {
      _saturation = 100 * delta / (max + min);
    } else {
      _saturation = 100 * delta / (2 - max - min);
    }
  }

  /// Computes [_red], [_green], and [_blue] based on [hue], [saturation], and
  /// [value].
  void _hslToRgb() {
    // Algorithm from the CSS3 spec: https://www.w3.org/TR/css3-color/#hsl-color.
    var scaledHue = hue / 360;
    var scaledSaturation = saturation / 100;
    var scaledLightness = lightness / 100;

    var m2 = scaledLightness <= 0.5
        ? scaledLightness * (scaledSaturation + 1)
        : scaledLightness +
            scaledSaturation -
            scaledLightness * scaledSaturation;
    var m1 = scaledLightness * 2 - m2;
    _red = fuzzyRound(_hueToRgb(m1, m2, scaledHue + 1 / 3) * 255);
    _green = fuzzyRound(_hueToRgb(m1, m2, scaledHue) * 255);
    _blue = fuzzyRound(_hueToRgb(m1, m2, scaledHue - 1 / 3) * 255);
  }

  /// An algorithm from the CSS3 spec:
  /// http://www.w3.org/TR/css3-color/#hsl-color.
  static num _hueToRgb(num m1, num m2, num hue) {
    if (hue < 0) hue += 1;
    if (hue > 1) hue -= 1;

    if (hue < 1 / 6) {
      return m1 + (m2 - m1) * hue * 6;
    } else if (hue < 1 / 2) {
      return m2;
    } else if (hue < 2 / 3) {
      return m1 + (m2 - m1) * (2 / 3 - hue) * 6;
    } else {
      return m1;
    }
  }

  /// Returns an `rgb()` or `rgba()` function call that will evaluate to this
  /// color.
  ///
  /// @nodoc
  @internal
  String toStringAsRgb() {
    var isOpaque = fuzzyEquals(alpha, 1);
    var buffer = StringBuffer(isOpaque ? "rgb" : "rgba")
      ..write("($red, $green, $blue");

    if (!isOpaque) {
      // Write the alpha as a SassNumber to ensure it's valid CSS.
      buffer.write(", ${SassNumber(alpha)}");
    }

    buffer.write(")");
    return buffer.toString();
  }
}

/// Extension methods that are only visible through the `sass_api` package.
///
/// These methods are considered less general-purpose and more liable to change
/// than the main [SassColor] interface.
///
/// {@category Value}
extension SassApiColor on SassColor {
  /// Whether the `red`, `green`, and `blue` fields have already been computed
  /// for this value.
  ///
  /// Note that these fields can always be safely computed after the fact; this
  /// just allows users such as the Sass embedded compiler to access whichever
  /// representation is readily available.
  bool get hasCalculatedRgb => _red != null;

  /// Whether the `hue`, `saturation`, and `lightness` fields have already been
  /// computed for this value.
  ///
  /// Note that these fields can always be safely computed after the fact; this
  /// just allows users such as the Sass embedded compiler to access whichever
  /// representation is readily available.
  bool get hasCalculatedHsl => _saturation != null;
}
