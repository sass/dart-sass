// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:source_span/source_span.dart';

import '../exception.dart';
import '../util/number.dart';
import '../value.dart';
import '../visitor/interface/value.dart';

/// Sets the span for [SassColor.original] to [span].
///
/// This is a separate function so it can be hidden in most exports.
void setOriginalSpan(SassColor color, SourceSpan span) {
  color._originalSpan = span;
}

// TODO(nweiz): track original representation.
/// A SassScript color.
class SassColor extends Value {
  /// This color's red channel, between `0` and `255`.
  int get red {
    if (_red == null) _hslToRgb();
    return _red;
  }

  int _red;

  /// This color's green channel, between `0` and `255`.
  int get green {
    if (_green == null) _hslToRgb();
    return _green;
  }

  int _green;

  /// This color's blue channel, between `0` and `255`.
  int get blue {
    if (_blue == null) _hslToRgb();
    return _blue;
  }

  int _blue;

  /// This color's hue, between `0` and `360`.
  num get hue {
    if (_hue == null) _rgbToHsl();
    return _hue;
  }

  num _hue;

  /// This color's saturation, a percentage between `0` and `100`.
  num get saturation {
    if (_saturation == null) _rgbToHsl();
    return _saturation;
  }

  num _saturation;

  /// This color's lightness, a percentage between `0` and `100`.
  num get lightness {
    if (_lightness == null) _rgbToHsl();
    return _lightness;
  }

  num _lightness;

  /// This color's alpha channel, between `0` and `1`.
  final num alpha;

  /// The original string representation of this color, or `null` if one is
  /// unavailable.
  String get original => _originalSpan?.text;

  /// The span tracking the location in which this color was originally defined.
  ///
  /// This is tracked as a span to avoid extra substring allocations.
  SourceSpan _originalSpan;

  /// Creates an RGB color.
  ///
  /// Throws a [RangeError] if [red], [green], and [blue] aren't between `0` and
  /// `255`, or if [alpha] isn't between `0` and `1`.
  SassColor.rgb(this._red, this._green, this._blue, [num alpha])
      : alpha = alpha == null ? 1 : fuzzyAssertRange(alpha, 0, 1, "alpha") {
    RangeError.checkValueInInterval(red, 0, 255, "red");
    RangeError.checkValueInInterval(green, 0, 255, "green");
    RangeError.checkValueInInterval(blue, 0, 255, "blue");
  }

  /// Creates an HSL color.
  ///
  /// Throws a [RangeError] if [saturation] or [lightness] aren't between `0`
  /// and `100`, or if [alpha] isn't between `0` and `1`.
  SassColor.hsl(num hue, num saturation, num lightness, [num alpha])
      : _hue = hue % 360,
        _saturation = fuzzyAssertRange(saturation, 0, 100, "saturation"),
        _lightness = fuzzyAssertRange(lightness, 0, 100, "lightness"),
        alpha = alpha == null ? 1 : fuzzyAssertRange(alpha, 0, 1, "alpha");

  SassColor._(this._red, this._green, this._blue, this._hue, this._saturation,
      this._lightness, this.alpha);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) => visitor.visitColor(this);

  SassColor assertColor([String name]) => this;

  /// Changes one or more of this color's RGB channels and returns the result.
  SassColor changeRgb({int red, int green, int blue, num alpha}) =>
      new SassColor.rgb(red ?? this.red, green ?? this.green, blue ?? this.blue,
          alpha ?? this.alpha);

  /// Changes one or more of this color's HSL channels and returns the result.
  SassColor changeHsl({num hue, num saturation, num lightness, num alpha}) =>
      new SassColor.hsl(hue ?? this.hue, saturation ?? this.saturation,
          lightness ?? this.lightness, alpha ?? this.alpha);

  /// Returns a new copy of this color with the alpha channel set to [alpha].
  SassColor changeAlpha(num alpha) => new SassColor._(_red, _green, _blue, _hue,
      _saturation, _lightness, fuzzyAssertRange(alpha, 0, 1, "alpha"));

  Value plus(Value other) {
    if (other is! SassNumber && other is! SassColor) return super.plus(other);
    throw new SassScriptException('Undefined operation "$this + $other".');
  }

  Value minus(Value other) {
    if (other is! SassNumber && other is! SassColor) return super.minus(other);
    throw new SassScriptException('Undefined operation "$this - $other".');
  }

  Value dividedBy(Value other) {
    if (other is! SassNumber && other is! SassColor) {
      return super.dividedBy(other);
    }
    throw new SassScriptException('Undefined operation "$this / $other".');
  }

  Value modulo(Value other) =>
      throw new SassScriptException('Undefined operation "$this % $other".');

  bool operator ==(other) =>
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
    // Algorithm from http://en.wikipedia.org/wiki/HSL_and_HSV#Conversion_from_RGB_to_HSL_or_HSV
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

    _lightness = 50 * (max + min);

    if (max == min) {
      _saturation = 0;
    } else if (_lightness < 50) {
      _saturation = 100 * delta / (max + min);
    } else {
      _saturation = 100 * delta / (2 - max - min);
    }
  }

  /// Computes [_red], [_green], and [_blue] based on [hue], [saturation], and
  /// [value].
  void _hslToRgb() {
    // Algorithm from the CSS3 spec: http://www.w3.org/TR/css3-color/#hsl-color.
    var scaledHue = hue / 360;
    var scaledSaturation = saturation / 100;
    var scaledLightness = lightness / 100;

    var m2 = scaledLightness <= 0.5
        ? scaledLightness * (scaledSaturation + 1)
        : scaledLightness +
            scaledSaturation -
            scaledLightness * scaledSaturation;
    var m1 = scaledLightness * 2 - m2;
    _red = _hueToRgb(m1, m2, scaledHue + 1 / 3);
    _green = _hueToRgb(m1, m2, scaledHue);
    _blue = _hueToRgb(m1, m2, scaledHue - 1 / 3);
  }

  /// An algorithm from the CSS3 spec:
  /// http://www.w3.org/TR/css3-color/#hsl-color.
  int _hueToRgb(num m1, num m2, num hue) {
    if (hue < 0) hue += 1;
    if (hue > 1) hue -= 1;

    num result;
    if (hue < 1 / 6) {
      result = m1 + (m2 - m1) * hue * 6;
    } else if (hue < 1 / 2) {
      result = m2;
    } else if (hue < 2 / 3) {
      result = m1 + (m2 - m1) * (2 / 3 - hue) * 6;
    } else {
      result = m1;
    }

    return fuzzyRound(result * 255);
  }
}
