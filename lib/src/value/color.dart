// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../deprecation.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../io.dart';
import '../util/nullable.dart';
import '../util/number.dart';
import '../value.dart';
import '../visitor/interface/value.dart';

export 'color/interpolation_method.dart';
export 'color/channel.dart';
export 'color/space.dart';

/// A SassScript color.
///
/// {@category Value}
@sealed
class SassColor extends Value {
  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

  /// This color's space.
  ColorSpace get space => _space;
  final ColorSpace _space;

  /// The values of this color's channels (excluding the alpha channel).
  ///
  /// Note that the semantics of each of these channels varies significantly
  /// based on the value of [space].
  List<double> get channels =>
      List.unmodifiable([channel0, channel1, channel2]);

  /// The values of this color's channels (excluding the alpha channel), or
  /// `null` for [missing] channels.
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  ///
  /// Note that the semantics of each of these channels varies significantly
  /// based on the value of [space].
  List<double?> get channelsOrNull =>
      List.unmodifiable([channel0OrNull, channel1OrNull, channel2OrNull]);

  /// This color's first channel.
  ///
  /// The semantics of this depend on the color space. Returns 0 for a missing
  /// channel.
  ///
  /// @nodoc
  @internal
  double get channel0 => channel0OrNull ?? 0;

  /// Returns whether this color's first channel is [missing].
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  ///
  /// @nodoc
  @internal
  bool get isChannel0Missing => channel0OrNull == null;

  /// Returns whether this color's first channel is [powerless].
  ///
  /// [powerless]: https://www.w3.org/TR/css-color-4/#powerless
  ///
  /// @nodoc
  @internal
  bool get isChannel0Powerless => switch (space) {
        ColorSpace.hsl => fuzzyEquals(channel1, 0) || fuzzyEquals(channel2, 0),
        ColorSpace.hwb => fuzzyEquals(channel1 + channel2, 100),
        _ => false
      };

  /// This color's first channel.
  ///
  /// The semantics of this depend on the color space. If this is `null`, that
  /// indicates a [missing] component.
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  final double? channel0OrNull;

  /// This color's second channel.
  ///
  /// The semantics of this depend on the color space. Returns 0 for a missing
  /// channel.
  ///
  /// @nodoc
  @internal
  double get channel1 => channel1OrNull ?? 0;

  /// Returns whether this color's second channel is [missing].
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  ///
  /// @nodoc
  @internal
  bool get isChannel1Missing => channel1OrNull == null;

  /// Returns whether this color's second channel is [powerless].
  ///
  /// [powerless]: https://www.w3.org/TR/css-color-4/#powerless
  ///
  /// @nodoc
  @internal
  bool get isChannel1Powerless => switch (space) {
        ColorSpace.hsl => fuzzyEquals(channel2, 0),
        ColorSpace.lab ||
        ColorSpace.oklab ||
        ColorSpace.lch ||
        ColorSpace.oklch =>
          fuzzyEquals(channel0, 0) || fuzzyEquals(channel0, 100),
        _ => false
      };

  /// This color's second channel.
  ///
  /// The semantics of this depend on the color space. If this is `null`, that
  /// indicates a [missing] component.
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  final double? channel1OrNull;

  /// Returns whether this color's third channel is [missing].
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  ///
  /// @nodoc
  @internal
  bool get isChannel2Missing => channel2OrNull == null;

  /// Returns whether this color's third channel is [powerless].
  ///
  /// [powerless]: https://www.w3.org/TR/css-color-4/#powerless
  ///
  /// @nodoc
  @internal
  bool get isChannel2Powerless => switch (space) {
        ColorSpace.lab ||
        ColorSpace.oklab =>
          fuzzyEquals(channel0, 0) || fuzzyEquals(channel0, 100),
        ColorSpace.lch || ColorSpace.oklch => fuzzyEquals(channel0, 0) ||
            fuzzyEquals(channel0, 100) ||
            fuzzyEquals(channel1, 0),
        _ => false
      };

  /// This color's third channel.
  ///
  /// The semantics of this depend on the color space. Returns 0 for a missing
  /// channel.
  ///
  /// @nodoc
  @internal
  double get channel2 => channel2OrNull ?? 0;

  /// This color's third channel.
  ///
  /// The semantics of this depend on the color space. If this is `null`, that
  /// indicates a [missing] component.
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  final double? channel2OrNull;

  /// The format in which this color was originally written and should be
  /// serialized in expanded mode, or `null` if the color wasn't written in a
  /// supported format.
  ///
  /// This is only set if `space` is `"rgb"`.
  ///
  /// @nodoc
  @internal
  final ColorFormat? format;

  /// This color's alpha channel, between `0` and `1`.
  double get alpha => _alpha;
  final double _alpha;

  /// Whether this is a legacy color—that is, a color defined using
  /// pre-color-spaces syntax that preserves comaptibility with old color
  /// behavior and semantics.
  bool get isLegacy => space.isLegacy;

  /// Whether this color is in-gamut for its color space.
  bool get isInGamut {
    // Strictly-bounded spaces can't even represent out-of-gamut colors, so
    // any color that exists must be bounded.
    if (!space.isBounded || space.isStrictlyBounded) return true;

    // There aren't (currently) any color spaces that are bounded but not
    // STRICTLY bounded, and have polar-angle channels.
    var channel0Info = space.channels[0] as LinearChannel;
    var channel1Info = space.channels[1] as LinearChannel;
    var channel2Info = space.channels[2] as LinearChannel;
    return fuzzyLessThanOrEquals(channel0, channel0Info.max) &&
        fuzzyGreaterThanOrEquals(channel0, channel0Info.min) &&
        fuzzyLessThanOrEquals(channel1, channel1Info.max) &&
        fuzzyGreaterThanOrEquals(channel1, channel1Info.min) &&
        fuzzyLessThanOrEquals(channel2, channel2Info.max) &&
        fuzzyGreaterThanOrEquals(channel2, channel2Info.min);
  }

  /// This color's red channel, between `0` and `255`.
  ///
  /// **Note:** This is rounded to the nearest integer, which may be lossy. Use
  /// [channel] instead to get the true red value.
  @Deprecated('Use channel() instead.')
  int get red => _legacyChannel(ColorSpace.rgb, 'red').round();

  /// This color's green channel, between `0` and `255`.
  ///
  /// **Note:** This is rounded to the nearest integer, which may be lossy. Use
  /// [channel] instead to get the true red value.
  @Deprecated('Use channel() instead.')
  int get green => _legacyChannel(ColorSpace.rgb, 'green').round();

  /// This color's blue channel, between `0` and `255`.
  ///
  /// **Note:** This is rounded to the nearest integer, which may be lossy. Use
  /// [channel] instead to get the true red value.
  @Deprecated('Use channel() instead.')
  int get blue => _legacyChannel(ColorSpace.rgb, 'blue').round();

  /// This color's hue, between `0` and `360`.
  @Deprecated('Use channel() instead.')
  double get hue => _legacyChannel(ColorSpace.hsl, 'hue') % 360;

  /// This color's saturation, a percentage between `0` and `100`.
  @Deprecated('Use channel() instead.')
  double get saturation => _legacyChannel(ColorSpace.hsl, 'saturation');

  /// This color's lightness, a percentage between `0` and `100`.
  @Deprecated('Use channel() instead.')
  double get lightness => _legacyChannel(ColorSpace.hsl, 'lightness');

  /// This color's whiteness, a percentage between `0` and `100`.
  @Deprecated('Use channel() instead.')
  double get whiteness => _legacyChannel(ColorSpace.hwb, 'whiteness');

  /// This color's blackness, a percentage between `0` and `100`.
  @Deprecated('Use channel() instead.')
  double get blackness => _legacyChannel(ColorSpace.hwb, 'blackness');

  /// Creates a color in [ColorSpace.rgb].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.rgb(num? red, num? green, num? blue, [num? alpha = 1]) =>
      SassColor.rgbInternal(red, green, blue, alpha);

  /// Like [SassColor.rgb], but also takes a [format] parameter.
  ///
  /// @nodoc
  @internal
  factory SassColor.rgbInternal(num? red, num? green, num? blue,
          [num? alpha, ColorFormat? format]) =>
      SassColor.forSpaceInternal(ColorSpace.rgb, red?.toDouble(),
          green?.toDouble(), blue?.toDouble(), alpha?.toDouble(), format);

  /// Creates a color in [ColorSpace.hsl].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.hsl(num? hue, num? saturation, num? lightness,
          [num? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.hsl,
          _normalizeHue(hue?.toDouble()),
          saturation.andThen((saturation) =>
              fuzzyAssertRange(saturation.toDouble(), 0, 100, "saturation")),
          lightness.andThen((lightness) =>
              fuzzyAssertRange(lightness.toDouble(), 0, 100, "lightness")),
          alpha?.toDouble());

  /// Creates a color in [ColorSpace.hwb].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.hwb(num? hue, num? whiteness, num? blackness,
          [num? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.hwb,
          _normalizeHue(hue?.toDouble()),
          whiteness.andThen((whiteness) =>
              fuzzyAssertRange(whiteness.toDouble(), 0, 100, "whiteness")),
          blackness.andThen((blackness) =>
              fuzzyAssertRange(blackness.toDouble(), 0, 100, "blackness")),
          alpha?.toDouble());

  /// Creates a color in [ColorSpace.srgb].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.srgb(double? red, double? green, double? blue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(ColorSpace.srgb, red, green, blue, alpha);

  /// Creates a color in [ColorSpace.srgbLinear].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.srgbLinear(double? red, double? green, double? blue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.srgbLinear, red, green, blue, alpha);

  /// Creates a color in [ColorSpace.displayP3].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.displayP3(double? red, double? green, double? blue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(ColorSpace.displayP3, red, green, blue, alpha);

  /// Creates a color in [ColorSpace.a98Rgb].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.a98Rgb(double? red, double? green, double? blue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(ColorSpace.a98Rgb, red, green, blue, alpha);

  /// Creates a color in [ColorSpace.prophotoRgb].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.prophotoRgb(double? red, double? green, double? blue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.prophotoRgb, red, green, blue, alpha);

  /// Creates a color in [ColorSpace.rec2020].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.rec2020(double? red, double? green, double? blue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(ColorSpace.rec2020, red, green, blue, alpha);

  /// Creates a color in [ColorSpace.xyzD50].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.xyzD50(double? x, double? y, double? z,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(ColorSpace.xyzD50, x, y, z, alpha);

  /// Creates a color in [ColorSpace.xyzD65].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.xyzD65(double? x, double? y, double? z,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(ColorSpace.xyzD65, x, y, z, alpha);

  /// Creates a color in [ColorSpace.lab].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.lab(double? lightness, double? a, double? b,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.lab,
          lightness.andThen(
              (lightness) => fuzzyAssertRange(lightness, 0, 100, "lightness")),
          a,
          b,
          alpha);

  /// Creates a color in [ColorSpace.lch].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.lch(double? lightness, double? chroma, double? hue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.lch,
          lightness.andThen(
              (lightness) => fuzzyAssertRange(lightness, 0, 100, "lightness")),
          chroma,
          _normalizeHue(hue),
          alpha);

  /// Creates a color in [ColorSpace.oklab].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.oklab(double? lightness, double? a, double? b,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.oklab,
          lightness.andThen(
              (lightness) => fuzzyAssertRange(lightness, 0, 100, "lightness")),
          a,
          b,
          alpha);

  /// Creates a color in [ColorSpace.oklch].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1`.
  factory SassColor.oklch(double? lightness, double? chroma, double? hue,
          [double? alpha = 1]) =>
      SassColor.forSpaceInternal(
          ColorSpace.oklch,
          lightness.andThen(
              (lightness) => fuzzyAssertRange(lightness, 0, 100, "lightness")),
          chroma,
          _normalizeHue(hue),
          alpha);

  /// Creates a color in the color space named [space].
  ///
  /// **Note:** Passing `null` to [alpha] represents a [missing component], not
  /// the default value of `1`
  ///
  /// [missing component]: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#missing_color_components
  ///
  /// Throws a [RangeError] if [alpha] isn't between `0` and `1` or if
  /// [channels] is the wrong length for [space].
  factory SassColor.forSpace(ColorSpace space, List<double?> channels,
      [double? alpha = 1]) {
    if (channels.length != space.channels.length) {
      throw RangeError.value(channels.length, "channels.length",
          'must be exactly ${space.channels.length} for color space "$space"');
    } else {
      var clampChannel0 = space.channels[0].name == "lightness";
      var clampChannel12 = space == ColorSpace.hsl || space == ColorSpace.hwb;
      return SassColor.forSpaceInternal(
          space,
          clampChannel0
              ? channels[0].andThen((value) => fuzzyClamp(value, 0, 100))
              : channels[0],
          clampChannel12
              ? channels[1].andThen((value) => fuzzyClamp(value, 0, 100))
              : channels[1],
          clampChannel12
              ? channels[2].andThen((value) => fuzzyClamp(value, 0, 100))
              : channels[2],
          alpha);
    }
  }

  /// Like [forSpace], but takes three channels explicitly rather than wrapping
  /// and unwrapping them in an array.
  ///
  /// @nodoc
  @internal
  SassColor.forSpaceInternal(this._space, this.channel0OrNull,
      this.channel1OrNull, this.channel2OrNull, double? alpha,
      [this.format])
      // TODO(nweiz): Support missing alpha channels.
      : _alpha =
            alpha.andThen((alpha) => fuzzyAssertRange(alpha, 0, 1, "alpha")) ??
                1.0 {
    assert(format == null || _space == ColorSpace.rgb);
    assert(
        !(space == ColorSpace.hsl || space == ColorSpace.hwb) ||
            (fuzzyCheckRange(channel1, 0, 100) != null &&
                fuzzyCheckRange(channel2, 0, 100) != null),
        "[BUG] Tried to create "
        "$_space(${channel0OrNull ?? 'none'}, ${channel1OrNull ?? 'none'}, "
        "${channel2OrNull ?? 'none'})");
    assert(
        space.channels[0].name != "lightness" ||
            fuzzyCheckRange(channel0, 0, 100) != null,
        "[BUG] Tried to create "
        "$_space(${channel0OrNull ?? 'none'}, ${channel1OrNull ?? 'none'}, "
        "${channel2OrNull ?? 'none'})");
    assert(space != ColorSpace.lms);

    _checkChannel(channel0OrNull, space.channels[0].name);
    _checkChannel(channel1OrNull, space.channels[1].name);
    _checkChannel(channel2OrNull, space.channels[2].name);
  }

  /// Throws a [RangeError] if [channel] isn't a finite number.
  void _checkChannel(double? channel, String name) {
    switch (channel) {
      case null:
        return;
      case double(isNaN: true):
        throw RangeError.value(channel, name, 'must be a number.');
      case double(isFinite: false):
        throw RangeError.value(channel, name, 'must be finite.');
    }
  }

  /// If [hue] isn't null, normalizes it to the range `[0, 360)`.
  static double? _normalizeHue(double? hue) {
    if (hue == null) return hue;
    return (hue % 360 + 360) % 360;
  }

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitColor(this);

  SassColor assertColor([String? name]) => this;

  /// Throws a [SassScriptException] if this isn't in a legacy color space.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). This is used for error reporting.
  ///
  /// @nodoc
  @internal
  void assertLegacy([String? name]) {
    if (isLegacy) return;
    throw SassScriptException(
        'Expected $this to be in the legacy RGB, HSL, or HWB color space.',
        name);
  }

  /// Returns the value of the given [channel] in this color, or throws a
  /// [SassScriptException] if it doesn't exist.
  ///
  /// If this came from a function argument, [colorName] is the argument name
  /// for this color and [channelName] is the argument name for [channel]
  /// (without the `$`). These are used for error reporting.
  double channel(String channel, {String? colorName, String? channelName}) {
    channel = channel.toLowerCase();
    var channels = space.channels;
    if (channel == channels[0].name) return channel0;
    if (channel == channels[1].name) return channel1;
    if (channel == channels[2].name) return channel2;

    throw SassScriptException(
        "Color $this doesn't have a channel named \"$channel\".", channelName);
  }

  /// Returns whether the given [channel] in this color is [missing].
  ///
  /// [missing]: https://www.w3.org/TR/css-color-4/#missing
  ///
  /// If this came from a function argument, [colorName] is the argument name
  /// for this color and [channelName] is the argument name for [channel]
  /// (without the `$`). These are used for error reporting.
  bool isChannelMissing(String channel,
      {String? colorName, String? channelName}) {
    channel = channel.toLowerCase();
    var channels = space.channels;
    if (channel == channels[0].name) return isChannel0Missing;
    if (channel == channels[1].name) return isChannel1Missing;
    if (channel == channels[2].name) return isChannel2Missing;

    throw SassScriptException(
        "Color $this doesn't have a channel named \"$channel\".", channelName);
  }

  /// Returns whether the given [channel] in this color is [powerless].
  ///
  /// [powerless]: https://www.w3.org/TR/css-color-4/#powerless
  ///
  /// If this came from a function argument, [colorName] is the argument name
  /// for this color and [channelName] is the argument name for [channel]
  /// (without the `$`). These are used for error reporting.
  bool isChannelPowerless(String channel,
      {String? colorName, String? channelName}) {
    channel = channel.toLowerCase();
    var channels = space.channels;
    if (channel == channels[0].name) return isChannel0Powerless;
    if (channel == channels[1].name) return isChannel1Powerless;
    if (channel == channels[2].name) return isChannel2Powerless;

    throw SassScriptException(
        "Color $this doesn't have a channel named \"$channel\".", channelName);
  }

  /// If this is a legacy color, converts it to the given [space] and then
  /// returns the given [channel].
  ///
  /// Otherwise, throws an exception.
  double _legacyChannel(ColorSpace space, String channel) {
    if (!isLegacy) {
      throw SassScriptException(
          "color.$channel() is only supported for legacy colors. Please use "
          "color.channel() instead with an explicit \$space argument.");
    }

    return toSpace(space).channel(channel);
  }

  /// Converts this color to [space].
  ///
  /// If this came from a function argument, [name] is the argument name for
  /// this color (without the `$`). It's used for error reporting.
  ///
  /// This currently can't produce an error, but it will likely do so in the
  /// future when Sass adds support for color spaces that don't support
  /// automatic conversions.
  SassColor toSpace(ColorSpace space) => this.space == space
      ? this
      : this.space.convert(space, channel0, channel1, channel2, alpha);

  /// Returns a copy of this color that's in-gamut in the current color space.
  SassColor toGamut() {
    if (isInGamut) return this;

    // Algorithm from https://www.w3.org/TR/css-color-4/#css-gamut-mapping-algorithm
    var originOklch = toSpace(ColorSpace.oklch);

    if (fuzzyGreaterThanOrEquals(originOklch.channel0, 1)) {
      return space == ColorSpace.rgb
          ? SassColor.rgb(255, 255, 255, alpha)
          : SassColor.forSpaceInternal(space, 1, 1, 1, alpha);
    } else if (fuzzyLessThanOrEquals(originOklch.channel0, 0)) {
      return SassColor.forSpaceInternal(space, 0, 0, 0, alpha);
    }

    // Always target RGB for legacy colors because HSL and HWB can't even
    // represent out-of-gamut colors.
    var targetSpace = isLegacy ? ColorSpace.rgb : space;

    var min = 0.0;
    var max = originOklch.channel1;
    while (true) {
      var chroma = (min + max) / 2;
      // Never null because [targetSpace] can't be HSL or HWB.
      var current = ColorSpace.oklch.convert(targetSpace, originOklch.channel0,
          chroma, originOklch.channel2, originOklch.alpha);
      if (current.isInGamut) {
        min = chroma;
        continue;
      }

      var clipped = _clip(current);
      if (_deltaEOK(clipped, current) < 0.02) return clipped;
      max = chroma;
    }
  }

  /// Returns [current] clipped into its space's gamut.
  SassColor _clip(SassColor current) {
    assert(!current.isInGamut);
    assert(current.space == space);

    return space == ColorSpace.rgb
        ? SassColor.rgb(
            fuzzyClamp(current.channel0, 0, 255),
            fuzzyClamp(current.channel1, 0, 255),
            fuzzyClamp(current.channel2, 0, 255),
            current.alpha)
        : SassColor.forSpaceInternal(
            space,
            fuzzyClamp(current.channel0, 0, 1),
            fuzzyClamp(current.channel1, 0, 1),
            fuzzyClamp(current.channel2, 0, 1),
            current.alpha);
  }

  /// Returns the ΔEOK measure between [color1] and [color2].
  double _deltaEOK(SassColor color1, SassColor color2) {
    // Algorithm from https://www.w3.org/TR/css-color-4/#color-difference-OK
    var lab1 = color1.toSpace(ColorSpace.oklab);
    var lab2 = color2.toSpace(ColorSpace.oklab);

    return math.sqrt(math.pow(lab1.channel0 - lab2.channel0, 2) +
        math.pow(lab1.channel1 - lab2.channel1, 2) +
        math.pow(lab1.channel2 - lab2.channel2, 2));
  }

  /// Changes one or more of this color's RGB channels and returns the result.
  @Deprecated('Use changeChannels() instead.')
  SassColor changeRgb({int? red, int? green, int? blue, num? alpha}) {
    if (!isLegacy) {
      throw SassScriptException(
          "color.changeRgb() is only supported for legacy colors. Please use "
          "color.changeChannels() instead with an explicit \$space argument.");
    }

    return SassColor.rgb(
        red?.toDouble() ?? channel('red'),
        green?.toDouble() ?? channel('green'),
        blue?.toDouble() ?? channel('blue'),
        alpha?.toDouble() ?? this.alpha);
  }

  /// Changes one or more of this color's HSL channels and returns the result.
  @Deprecated('Use changeChannels() instead.')
  SassColor changeHsl({num? hue, num? saturation, num? lightness, num? alpha}) {
    if (!isLegacy) {
      throw SassScriptException(
          "color.changeHsl() is only supported for legacy colors. Please use "
          "color.changeChannels() instead with an explicit \$space argument.");
    }

    return SassColor.hsl(
            hue?.toDouble() ?? this.hue,
            saturation?.toDouble() ?? this.saturation,
            lightness?.toDouble() ?? this.lightness,
            alpha?.toDouble() ?? this.alpha)
        .toSpace(space);
  }

  /// Changes one or more of this color's HWB channels and returns the result.
  @Deprecated('Use changeChannels() instead.')
  SassColor changeHwb({num? hue, num? whiteness, num? blackness, num? alpha}) {
    if (!isLegacy) {
      throw SassScriptException(
          "color.changeHsl() is only supported for legacy colors. Please use "
          "color.changeChannels() instead with an explicit \$space argument.");
    }

    return SassColor.hwb(
            hue?.toDouble() ?? this.hue,
            whiteness?.toDouble() ?? this.whiteness,
            blackness?.toDouble() ?? this.blackness,
            alpha?.toDouble() ?? this.alpha + 0.0)
        .toSpace(space);
  }

  /// Returns a new copy of this color with the alpha channel set to [alpha].
  SassColor changeAlpha(num alpha) => SassColor.forSpaceInternal(
      space, channel0, channel1, channel2, alpha.toDouble());

  /// Changes one or more of this color's channels and returns the result.
  ///
  /// The keys of [newValues] are channel names and the values are the new
  /// values of those channels.
  ///
  /// If [space] is passed, this converts this color to [space], sets the
  /// channels, then converts the result back to its original color space.
  ///
  /// Throws a [SassScriptException] if any of the keys aren't valid channel
  /// names for this color, or if the same channel is set multiple times.
  ///
  /// If this color came from a function argument, [colorName] is the argument
  /// name (without the `$`). This is used for error reporting.
  SassColor changeChannels(Map<String, double> newValues,
      {ColorSpace? space, String? colorName}) {
    if (newValues.isEmpty) {
      // If space conversion produces an error, we still want to expose that
      // error even if there's nothing to change.
      if (space != null && space != this.space) toSpace(space);
      return this;
    }

    if (space != null && space != this.space) {
      return toSpace(space)
          .changeChannels(newValues, colorName: colorName)
          .toSpace(space);
    }

    double? new0;
    double? new1;
    double? new2;
    double? alpha;
    var channels = this.space.channels;

    void setChannel0(double value) {
      if (new0 != null) {
        throw SassScriptException(
            'Multiple values supplied for "${channels[0]}": $new0 and '
            '$value.',
            colorName);
      }
      new0 = value;
    }

    void setChannel1(double value) {
      if (new1 != null) {
        throw SassScriptException(
            'Multiple values supplied for "${channels[1]}": $new1 and '
            '$value.',
            colorName);
      }
      new1 = value;
    }

    void setChannel2(double value) {
      if (new2 != null) {
        throw SassScriptException(
            'Multiple values supplied for "${channels[2]}": $new2 and '
            '$value.',
            colorName);
      }
      new2 = value;
    }

    for (var entry in newValues.entries) {
      var channel = entry.key.toLowerCase();
      if (channel == channels[0].name) {
        setChannel0(entry.value);
      } else if (channel == channels[1].name) {
        setChannel1(entry.value);
      } else if (channel == channels[2].name) {
        setChannel2(entry.value);
      } else if (channel == 'alpha') {
        if (alpha != null) {
          throw SassScriptException(
              'Multiple values supplied for "alpha": $alpha and '
              '${entry.value}.',
              colorName);
        }
        alpha = entry.value;
      } else {
        throw SassScriptException(
            "Color $this doesn't have a channel named \"$channel\".",
            colorName);
      }
    }

    return SassColor.forSpaceInternal(
        this.space,
        _clampChannelIfNecessary(new0, this.space, 0) ?? channel0,
        _clampChannelIfNecessary(new1, this.space, 1) ?? channel1,
        _clampChannelIfNecessary(new2, this.space, 2) ?? channel2,
        alpha ?? this.alpha);
  }

  /// If [space] is strictly bounded and its [index]th channel isn't polar,
  /// clamps [value] between its minimum and maximum.
  double? _clampChannelIfNecessary(double? value, ColorSpace space, int index) {
    if (value == null) return value;
    if (!space.isStrictlyBounded) return value;
    var channel = space.channels[index];
    if (channel is! LinearChannel) return value;
    return fuzzyClamp(value, channel.min, channel.max);
  }

  /// Returns a color partway between [this] and [other] according to [method],
  /// as defined by the CSS Color 4 [color interpolation] procedure.
  ///
  /// [color interpolation]: https://www.w3.org/TR/css-color-4/#interpolation
  ///
  /// The [weight] is a number between 0 and 1 that indicates how much of [this]
  /// should be in the resulting color. It defaults to 0.5.
  SassColor interpolate(SassColor other, InterpolationMethod method,
      {double? weight}) {
    weight ??= 0.5;

    if (fuzzyEquals(weight, 0)) return other;
    if (fuzzyEquals(weight, 1)) return this;

    var color1 = toSpace(method.space);
    var color2 = other.toSpace(method.space);

    if (weight < 0 || weight > 1) {
      throw RangeError.range(weight, 0, 1, 'weight');
    }

    // If either color is missing a channel _and_ that channel is analogous with
    // one in the output space, then the output channel should take on the other
    // color's value.
    var missing1_0 = _isAnalogousChannelMissing(this, color1, 0);
    var missing1_1 = _isAnalogousChannelMissing(this, color1, 1);
    var missing1_2 = _isAnalogousChannelMissing(this, color1, 2);
    var missing2_0 = _isAnalogousChannelMissing(other, color2, 0);
    var missing2_1 = _isAnalogousChannelMissing(other, color2, 1);
    var missing2_2 = _isAnalogousChannelMissing(other, color2, 2);
    var channel1_0 = (missing1_0 ? color2 : color1).channel0;
    var channel1_1 = (missing1_1 ? color2 : color1).channel1;
    var channel1_2 = (missing1_2 ? color2 : color1).channel2;
    var channel2_0 = (missing2_0 ? color1 : color2).channel0;
    var channel2_1 = (missing2_1 ? color1 : color2).channel1;
    var channel2_2 = (missing2_2 ? color1 : color2).channel2;

    var thisMultiplier = alpha * weight;
    var otherMultiplier = other.alpha * (1 - weight);
    var mixedAlpha = alpha * weight + other.alpha * (1 - weight);
    var mixed0 = missing1_0 && missing2_0
        ? null
        : (channel1_0 * thisMultiplier + channel2_0 * otherMultiplier) /
            mixedAlpha;
    var mixed1 = missing1_1 && missing2_1
        ? null
        : (channel1_1 * thisMultiplier + channel2_1 * otherMultiplier) /
            mixedAlpha;
    var mixed2 = missing1_2 && missing2_2
        ? null
        : (channel1_2 * thisMultiplier + channel2_2 * otherMultiplier) /
            mixedAlpha;

    return switch (method.space) {
      ColorSpace.hsl || ColorSpace.hwb => SassColor.forSpaceInternal(
          method.space,
          missing1_0 && missing2_0
              ? null
              : _interpolateHues(channel1_0, channel2_0, method.hue!, weight),
          mixed1,
          mixed2,
          mixedAlpha),
      ColorSpace.lch || ColorSpace.oklch => SassColor.forSpaceInternal(
          method.space,
          mixed0,
          mixed1,
          missing1_2 && missing2_2
              ? null
              : _interpolateHues(channel1_2, channel2_2, method.hue!, weight),
          mixedAlpha),
      _ => SassColor.forSpaceInternal(
          method.space, mixed0, mixed1, mixed2, mixedAlpha)
    }
        .toSpace(space);
  }

  /// Returns whether [output], which was converted to its color space from
  /// [original], should be considered to have a missing channel at
  /// [outputChannelIndex].
  ///
  /// This includes channels that are analogous to missing channels in
  /// [original].
  bool _isAnalogousChannelMissing(
      SassColor original, SassColor output, int outputChannelIndex) {
    if (output.channelsOrNull[outputChannelIndex] == null) return true;
    if (identical(original, output)) return false;

    var outputChannel = output.space.channels[outputChannelIndex];
    var originalChannel =
        original.space.channels.firstWhereOrNull(outputChannel.isAnalogous);
    if (originalChannel == null) return false;

    return original.isChannelMissing(originalChannel.name);
  }

  /// Returns a hue partway between [hue1] and [hue2] according to [method].
  ///
  /// The [weight] is a number between 0 and 1 that indicates how much of [hue1]
  /// should be in the resulting hue.
  double _interpolateHues(
      double hue1, double hue2, HueInterpolationMethod method, double weight) {
    // Algorithms from https://www.w3.org/TR/css-color-4/#hue-interpolation
    switch (method) {
      case HueInterpolationMethod.shorter:
        switch (hue2 - hue1) {
          case > 180:
            hue1 += 360;
          case < -180:
            hue2 += 360;
        }

      case HueInterpolationMethod.longer:
        switch (hue2 - hue1) {
          case > 0 && < 180:
            hue2 += 360;
          case > -180 && <= 0:
            hue1 += 360;
        }

      case HueInterpolationMethod.increasing when hue2 < hue1:
        hue2 += 360;

      case HueInterpolationMethod.decreasing when hue1 < hue2:
        hue1 += 360;

      case _: // do nothing
    }

    return hue1 * weight + hue2 * (1 - weight);
  }

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

  operator ==(Object other) {
    if (other is! SassColor) return false;

    if (isLegacy) {
      if (!other.isLegacy) return false;
      if (!fuzzyEquals(alpha, other.alpha)) return false;
      if (space == ColorSpace.rgb && other.space == ColorSpace.rgb) {
        return fuzzyEquals(channel0, other.channel0) &&
            fuzzyEquals(channel1, other.channel1) &&
            fuzzyEquals(channel2, other.channel2);
      } else {
        return toSpace(ColorSpace.rgb) == other.toSpace(ColorSpace.rgb);
      }
    }

    return space == other.space &&
        fuzzyEquals(channel0, other.channel0) &&
        fuzzyEquals(channel1, other.channel1) &&
        fuzzyEquals(channel2, other.channel2) &&
        fuzzyEquals(alpha, other.alpha);
  }

  int get hashCode {
    if (isLegacy) {
      var rgb = toSpace(ColorSpace.rgb);
      return fuzzyHashCode(rgb.channel0) ^
          fuzzyHashCode(rgb.channel1) ^
          fuzzyHashCode(rgb.channel2) ^
          fuzzyHashCode(alpha);
    } else {
      return space.hashCode ^
          fuzzyHashCode(channel0) ^
          fuzzyHashCode(channel1) ^
          fuzzyHashCode(channel2) ^
          fuzzyHashCode(alpha);
    }
  }
}

/// A union interface of possible formats in which a Sass color could be
/// defined.
///
/// When a color is serialized in expanded mode, it should preserve its original
/// format.
@internal
abstract class ColorFormat {
  /// A color defined using the `rgb()` or `rgba()` functions.
  static const rgbFunction = _ColorFormatEnum("rgbFunction");
}

/// The class for enum values of the [ColorFormat] type.
@sealed
class _ColorFormatEnum implements ColorFormat {
  final String _name;

  const _ColorFormatEnum(this._name);

  String toString() => _name;
}

/// A [ColorFormat] where the color is serialized as the exact same text that
/// was used to specify it originally.
///
/// This is tracked as a span rather than a string to avoid extra substring
/// allocations.
@internal
@sealed
class SpanColorFormat implements ColorFormat {
  /// The span tracking the location in which this color was originally defined.
  final FileSpan _span;

  /// The original string that was used to define this color in the Sass source.
  String get original => _span.text;

  SpanColorFormat(this._span);
}
