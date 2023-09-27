// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../value.dart';
import '../reflection.dart';
import '../utils.dart';

/// The JavaScript `SassColor` class.
final JSClass colorClass = () {
  var jsClass = createJSClass('sass.SassColor',
      (Object self, _ConstructionOptions options) {
    var constructionSpace = _constructionSpace(options);
    switch (constructionSpace) {
      case ColorSpace.rgb:
        _checkNullAlphaDeprecation(options);
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.red),
            _parseChannelValue(options.green),
            _parseChannelValue(options.blue),
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.hsl:
        _checkNullAlphaDeprecation(options);
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.hue),
            _parseChannelValue(options.saturation),
            _parseChannelValue(options.lightness),
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.hwb:
        _checkNullAlphaDeprecation(options);
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.hue),
            _parseChannelValue(options.whiteness),
            _parseChannelValue(options.blackness),
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.lab:
      case ColorSpace.oklab:
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.lightness),
            _parseChannelValue(options.a),
            _parseChannelValue(options.b),
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.lch:
      case ColorSpace.oklch:
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.lightness),
            _parseChannelValue(options.chroma),
            _parseChannelValue(options.hue),
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.srgb:
      case ColorSpace.srgbLinear:
      case ColorSpace.displayP3:
      case ColorSpace.a98Rgb:
      case ColorSpace.prophotoRgb:
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.red),
            _parseChannelValue(options.green),
            _parseChannelValue(options.blue),
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.xyzD50:
      // `xyz` name is mapped to `xyzD65` space.
      case ColorSpace.xyzD65:
        return SassColor.forSpaceInternal(
            constructionSpace,
            _parseChannelValue(options.x),
            _parseChannelValue(options.y),
            _parseChannelValue(options.z),
            _handleUndefinedAlpha(options.alpha));

      default:
        throw "Unreachable";
    }
  });

  SassColor legacyChange(SassColor self, _Channels options) {
    if (options.whiteness != null || options.blackness != null) {
      return self.changeHwb(
          hue: options.hue ?? self.hue,
          whiteness: options.whiteness ?? self.whiteness,
          blackness: options.blackness ?? self.blackness,
          alpha: options.alpha ?? self.alpha);
    } else if (options.hue != null ||
        options.saturation != null ||
        options.lightness != null) {
      return self.changeHsl(
          hue: options.hue ?? self.hue,
          saturation: options.saturation ?? self.saturation,
          lightness: options.lightness ?? self.lightness,
          alpha: options.alpha ?? self.alpha);
    } else if (options.red != null ||
        options.green != null ||
        options.blue != null) {
      return self.changeChannels({
        if (options.red case var red?) "red": red,
        if (options.green case var green?) "green": green,
        if (options.blue case var blue?) "blue": blue,
        if (options.alpha case var alpha?) "alpha": alpha
      });
    } else {
      return self.changeAlpha(options.alpha ?? self.alpha);
    }
  }

  jsClass.defineMethod('legacyChange', legacyChange);

  jsClass.defineMethod(
      'change', (SassColor self, _ConstructionOptions options) {});

  // @todo: Add deprecation warnings to all these getters
  jsClass.defineGetters({
    'red': (SassColor self) => self.red,
    'green': (SassColor self) => self.green,
    'blue': (SassColor self) => self.blue,
    'hue': (SassColor self) => self.hue,
    'saturation': (SassColor self) => self.saturation,
    'lightness': (SassColor self) => self.lightness,
    'whiteness': (SassColor self) => self.whiteness,
    'blackness': (SassColor self) => self.blackness,
    'alpha': (SassColor self) => self.alpha,
  });

  jsClass.defineGetters({
    'space': (SassColor self) => self.space.name,
    'isLegacy': (SassColor self) => self.isLegacy,
  });

  jsClass.defineMethod('toSpace', (SassColor self, String space) {
    if (self.space.name == space) {
      return self;
    }
    ColorSpace spaceClass = ColorSpace.fromName(space);
    return self.toSpace(spaceClass);
  });
  jsClass.defineMethod('isInGamut', (SassColor self, String? space) {
    String spaceName = space ?? self.space.name;
    ColorSpace spaceClass = ColorSpace.fromName(spaceName);
    SassColor color = self.toSpace(spaceClass);
    return color.isInGamut;
  });
  jsClass.defineMethod('toGamut', (SassColor self, String? space) {
    String spaceName = space ?? self.space.name;
    ColorSpace spaceClass = ColorSpace.fromName(spaceName);
    SassColor color = self.toSpace(spaceClass);
    return color.toGamut();
  });

  jsClass.defineGetter(
      'channelsOrNull', (SassColor self) => self.channelsOrNull);

  jsClass.defineGetter('channels', (SassColor self) {
    final channelsOrNull = self.channelsOrNull;
    var channels = <num>[];
    for (final channel in channelsOrNull) {
      final value = channel ?? 0;
      channels.add(value);
    }
    return channels;
  });

  jsClass.defineMethod('channel',
      (SassColor self, String channel, ChannelOptions options) {
    String initialSpace = self.space.name;
    String space = options.space ?? initialSpace;
    ColorSpace spaceClass = ColorSpace.fromName(space);

    SassColor color = self.toSpace(spaceClass);

    return color.channel(channel);
  });
  jsClass.defineMethod('isChannelMissing', (SassColor self, String channel) {});
  jsClass.defineGetter('isAlphaMissing', (SassColor self) {});
  jsClass.defineMethod(
      'isChannelPowerless', (SassColor self, ChannelOptions options) {});

  jsClass.defineMethod(
      'interpolate', (SassColor self, InterpolationOptions options) {});

  getJSClass(SassColor.rgb(0, 0, 0)).injectSuperclass(jsClass);
  return jsClass;
}();

/// Converts an undefined [alpha] to 1.
///
/// This ensures that an explicitly null alpha will be treated as a missing
/// component.
double? _handleUndefinedAlpha(double? alpha) => isUndefined(alpha) ? 1 : alpha;

/// This procedure takes a channel value `value`, and returns the special value
/// `none` if the value is `null`.
/// @todo needs to be implemented
double? _parseChannelValue(double? value) => value;

/// This procedure takes a `channel` name, an object `changes` and a SassColor
/// `initial` and returns the result of applying the change for `channel` to
/// `initial`.\
double? _changeComponentValue(
    SassColor initial, String channel, _ConstructionOptions changes) {
  return null;
}

/// Determines the construction space based on the provided options.
ColorSpace _constructionSpace(_ConstructionOptions options) {
  if (options.space != null) return ColorSpace.fromName(options.space!);
  if (options.red != null) return ColorSpace.rgb;
  if (options.saturation != null) return ColorSpace.hsl;
  if (options.whiteness != null) return ColorSpace.hwb;
  throw "No color space found";
}

void _checkNullAlphaDeprecation(_ConstructionOptions options) {
  // @todo Verify if options.space is equivalent to "not set"
  if (options.alpha == null && options.space == null) {
    // emit deprecation
  }
}

@JS()
@anonymous
class _Channels {
  external double? get red;
  external double? get green;
  external double? get blue;
  external double? get hue;
  external double? get saturation;
  external double? get lightness;
  external double? get whiteness;
  external double? get blackness;
  external double? get alpha;
  external double? get a;
  external double? get b;
  external double? get x;
  external double? get y;
  external double? get z;
  external double? get chroma;
}

@JS()
@anonymous
class _ConstructionOptions extends _Channels {
  external String? get space;
}

@JS()
@anonymous
class ChannelOptions {
  String? space;
}

@JS()
@anonymous
class InterpolationOptions {
  late SassColor color2;
  double? weight;
  String? method;
}
