// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:node_interop/js.dart';

import '../../deprecation.dart';
import '../../evaluation_context.dart';
import '../../value.dart';
import '../immutable.dart';
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
        return SassColor.rgb(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.hsl:
        _checkNullAlphaDeprecation(options);
        return SassColor.hsl(options.hue, options.saturation, options.lightness,
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.hwb:
        _checkNullAlphaDeprecation(options);
        return SassColor.hwb(options.hue, options.whiteness, options.blackness,
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.lab:
        return SassColor.lab(options.lightness, options.a, options.b,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.oklab:
        return SassColor.oklab(options.lightness, options.a, options.b,
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.lch:
        return SassColor.lch(options.lightness, options.chroma, options.hue,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.oklch:
        return SassColor.oklch(options.lightness, options.chroma, options.hue,
            _handleUndefinedAlpha(options.alpha));

      case ColorSpace.srgb:
        return SassColor.srgb(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.srgbLinear:
        return SassColor.srgbLinear(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.displayP3:
        return SassColor.displayP3(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.a98Rgb:
        return SassColor.a98Rgb(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.prophotoRgb:
        return SassColor.prophotoRgb(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.rec2020:
        return SassColor.rec2020(options.red, options.green, options.blue,
            _handleUndefinedAlpha(options.alpha));

      // `xyz` name is mapped to `xyzD65` space.
      case ColorSpace.xyzD50:
        return SassColor.xyzD50(options.x, options.y, options.z,
            _handleUndefinedAlpha(options.alpha));
      case ColorSpace.xyzD65:
        return SassColor.xyzD65(options.x, options.y, options.z,
            _handleUndefinedAlpha(options.alpha));

      default:
        throw "Unreachable";
    }
  });

  jsClass.defineMethods({
    'equals': (SassColor self, Object other) => self == other,
    'hashCode': (SassColor self) => self.hashCode,
    'toSpace': (SassColor self, String space) => _toSpace(self, space),
    'isInGamut': (SassColor self, [String? space]) =>
        _toSpace(self, space).isInGamut,
    'toGamut': (SassColor self, _ToGamutOptions options) {
      var originalSpace = self.space;
      return _toSpace(self, options.space)
          .toGamut(GamutMapMethod.fromName(options.method))
          .toSpace(originalSpace);
    },
    'channel': (SassColor self, String channel, [_ChannelOptions? options]) =>
        _toSpace(self, options?.space).channel(channel),
    'isChannelMissing': (SassColor self, String channel) =>
        self.isChannelMissing(channel),
    'isChannelPowerless': (SassColor self, String channel,
            [_ChannelOptions? options]) =>
        _toSpace(self, options?.space).isChannelPowerless(channel),
    'change': (SassColor self, _ConstructionOptions options) {
      var spaceSetExplicitly = options.space != null;
      var space =
          spaceSetExplicitly ? ColorSpace.fromName(options.space!) : self.space;

      if (self.isLegacy && !spaceSetExplicitly) {
        if (hasProperty(options, 'whiteness') ||
            hasProperty(options, 'blackness')) {
          space = ColorSpace.hwb;
        } else if (hasProperty(options, 'hue') &&
            self.space == ColorSpace.hwb) {
          space = ColorSpace.hwb;
        } else if (hasProperty(options, 'hue') ||
            hasProperty(options, 'saturation') ||
            hasProperty(options, 'lightness')) {
          space = ColorSpace.hsl;
        } else if (hasProperty(options, 'red') ||
            hasProperty(options, 'green') ||
            hasProperty(options, 'blue')) {
          space = ColorSpace.rgb;
        }
        if (space != self.space) {
          warnForDeprecationFromApi(
              "Changing a channel not in this color's space without explicitly specifying "
              "the `space` option is deprecated."
              "\n"
              "More info: https://sass-lang.com/d/color-4-api",
              Deprecation.color4Api);
        }
      }

      for (final key in objectKeys(options)) {
        if (['alpha', 'space'].contains(key)) continue;
        if (!space.channels.any((channel) => channel.name == key)) {
          jsThrow(JsError("`$key` is not a valid channel in `$space`."));
        }
      }

      var color = self.toSpace(space);

      SassColor changedColor;

      double? changedValue(String channel) {
        return _changeComponentValue(color, channel, options);
      }

      switch (space) {
        case ColorSpace.hsl when spaceSetExplicitly:
          changedColor = SassColor.hsl(
              changedValue('hue'),
              changedValue('saturation'),
              changedValue('lightness'),
              changedValue('alpha'));
          break;

        case ColorSpace.hsl:
          if (isNull(options.hue)) {
            _emitColor4ApiNullDeprecation('hue');
          } else if (isNull(options.saturation)) {
            _emitColor4ApiNullDeprecation('saturation');
          } else if (isNull(options.lightness)) {
            _emitColor4ApiNullDeprecation('lightness');
          }
          if (isNull(options.alpha)) {
            _emitNullAlphaDeprecation();
          }
          changedColor = SassColor.hsl(
              options.hue ?? color.channel('hue'),
              options.saturation ?? color.channel('saturation'),
              options.lightness ?? color.channel('lightness'),
              options.alpha ?? color.channel('alpha'));
          break;

        case ColorSpace.hwb when spaceSetExplicitly:
          changedColor = SassColor.hwb(
              changedValue('hue'),
              changedValue('whiteness'),
              changedValue('blackness'),
              changedValue('alpha'));
          break;

        case ColorSpace.hwb:
          if (isNull(options.hue)) {
            _emitColor4ApiNullDeprecation('hue');
          } else if (isNull(options.whiteness)) {
            _emitColor4ApiNullDeprecation('whiteness');
          } else if (isNull(options.blackness)) {
            _emitColor4ApiNullDeprecation('blackness');
          }
          if (isNull(options.alpha)) _emitNullAlphaDeprecation();
          changedColor = SassColor.hwb(
              options.hue ?? color.channel('hue'),
              options.whiteness ?? color.channel('whiteness'),
              options.blackness ?? color.channel('blackness'),
              options.alpha ?? color.channel('alpha'));

          break;

        case ColorSpace.rgb when spaceSetExplicitly:
          changedColor = SassColor.rgb(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;

        case ColorSpace.rgb:
          if (isNull(options.red)) {
            _emitColor4ApiNullDeprecation('red');
          } else if (isNull(options.green)) {
            _emitColor4ApiNullDeprecation('green');
          } else if (isNull(options.blue)) {
            _emitColor4ApiNullDeprecation('blue');
          }
          if (isNull(options.alpha)) {
            _emitNullAlphaDeprecation();
          }
          changedColor = SassColor.rgb(
              options.red ?? color.channel('red'),
              options.green ?? color.channel('green'),
              options.blue ?? color.channel('blue'),
              options.alpha ?? color.channel('alpha'));
          break;

        case ColorSpace.lab:
          changedColor = SassColor.lab(changedValue('lightness'),
              changedValue('a'), changedValue('b'), changedValue('alpha'));
          break;

        case ColorSpace.oklab:
          changedColor = SassColor.oklab(changedValue('lightness'),
              changedValue('a'), changedValue('b'), changedValue('alpha'));
          break;

        case ColorSpace.lch:
          changedColor = SassColor.lch(
              changedValue('lightness'),
              changedValue('chroma'),
              changedValue('hue'),
              changedValue('alpha'));
          break;
        case ColorSpace.oklch:
          changedColor = SassColor.oklch(
              changedValue('lightness'),
              changedValue('chroma'),
              changedValue('hue'),
              changedValue('alpha'));
          break;

        case ColorSpace.a98Rgb:
          changedColor = SassColor.a98Rgb(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;
        case ColorSpace.displayP3:
          changedColor = SassColor.displayP3(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;
        case ColorSpace.prophotoRgb:
          changedColor = SassColor.prophotoRgb(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;
        case ColorSpace.rec2020:
          changedColor = SassColor.rec2020(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;
        case ColorSpace.srgb:
          changedColor = SassColor.srgb(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;
        case ColorSpace.srgbLinear:
          changedColor = SassColor.srgbLinear(
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
          break;

        case ColorSpace.xyzD50:
          changedColor = SassColor.forSpaceInternal(space, changedValue('x'),
              changedValue('y'), changedValue('z'), changedValue('alpha'));
          break;
        case ColorSpace.xyzD65:
          changedColor = SassColor.forSpaceInternal(space, changedValue('x'),
              changedValue('y'), changedValue('z'), changedValue('alpha'));
          break;

        default:
          throw "No space set";
      }

      return changedColor.toSpace(self.space);
    },
    'interpolate':
        (SassColor self, SassColor color2, _InterpolationOptions options) {
      InterpolationMethod interpolationMethod;

      if (options.method case var method?) {
        var hue = HueInterpolationMethod.values.byName(method);
        interpolationMethod = InterpolationMethod(self.space, hue);
      } else if (!self.space.isPolar) {
        interpolationMethod = InterpolationMethod(self.space);
      } else {
        interpolationMethod =
            InterpolationMethod(self.space, HueInterpolationMethod.shorter);
      }

      return self.interpolate(color2, interpolationMethod,
          weight: options.weight);
    }
  });

  jsClass.defineGetters({
    'red': (SassColor self) {
      _emitColor4ApiChannelDeprecation('red');
      return self.red;
    },
    'green': (SassColor self) {
      _emitColor4ApiChannelDeprecation('green');
      return self.green;
    },
    'blue': (SassColor self) {
      _emitColor4ApiChannelDeprecation('blue');
      return self.blue;
    },
    'hue': (SassColor self) {
      _emitColor4ApiChannelDeprecation('hue');
      return self.hue;
    },
    'saturation': (SassColor self) {
      _emitColor4ApiChannelDeprecation('saturation');
      return self.saturation;
    },
    'lightness': (SassColor self) {
      _emitColor4ApiChannelDeprecation('lightness');
      return self.lightness;
    },
    'whiteness': (SassColor self) {
      _emitColor4ApiChannelDeprecation('whiteness');
      return self.whiteness;
    },
    'blackness': (SassColor self) {
      _emitColor4ApiChannelDeprecation('blackness');
      return self.blackness;
    },
    'alpha': (SassColor self) => self.alpha,
    'space': (SassColor self) => self.space.name,
    'isLegacy': (SassColor self) => self.isLegacy,
    'channelsOrNull': (SassColor self) => ImmutableList(self.channelsOrNull),
    'channels': (SassColor self) => ImmutableList(self.channels)
  });

  getJSClass(SassColor.rgb(0, 0, 0)).injectSuperclass(jsClass);
  return jsClass;
}();

/// Converts an undefined [alpha] to 1.
///
/// This ensures that an explicitly null alpha will be treated as a missing
/// component.
double? _handleUndefinedAlpha(double? alpha) => isUndefined(alpha) ? 1 : alpha;

/// This procedure takes a `channel` name, an object `changes` and a SassColor
/// `initial` and returns the result of applying the change for `channel` to
/// `initial`.
double? _changeComponentValue(
        SassColor initial, String channel, _ConstructionOptions changes) =>
    hasProperty(changes, channel) && !isUndefined(getProperty(changes, channel))
        ? getProperty(changes, channel)
        : initial.channel(channel);

/// Determines the construction space based on the provided options.
ColorSpace _constructionSpace(_ConstructionOptions options) {
  if (options.space != null) return ColorSpace.fromName(options.space!);
  if (options.red != null) return ColorSpace.rgb;
  if (options.saturation != null) return ColorSpace.hsl;
  if (options.whiteness != null) return ColorSpace.hwb;
  throw "No color space found";
}

// Return a SassColor in a named space, or in its original space.
SassColor _toSpace(SassColor self, String? space) {
  return self.toSpace(ColorSpace.fromName(space ?? self.space.name));
}

// If alpha is explicitly null and space is not set, emit deprecation.
void _checkNullAlphaDeprecation(_ConstructionOptions options) {
  if (!isUndefined(options.alpha) &&
      identical(options.alpha, null) &&
      identical(options.space, null)) {
    _emitNullAlphaDeprecation();
  }
}

// Warn users about null-alpha deprecation.
void _emitNullAlphaDeprecation() {
  warnForDeprecationFromApi(
      "Passing `alpha: null` without setting `space` is deprecated."
      "\n"
      "More info: https://sass-lang.com/d/null-alpha",
      Deprecation.nullAlpha);
}

// Warn users about `null` channel values without setting `space`.
void _emitColor4ApiNullDeprecation(String name) {
  warnForDeprecationFromApi(
      "Passing `$name: null` without setting `space` is deprecated."
      "\n"
      "More info: https://sass-lang.com/d/color-4-api",
      Deprecation.color4Api);
}

// Warn users about legacy color channel getters.
void _emitColor4ApiChannelDeprecation(String name) {
  warnForDeprecationFromApi(
      "$name is deprecated, use `channel` instead."
      "\n"
      "More info: https://sass-lang.com/d/color-4-api",
      Deprecation.color4Api);
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
class _ChannelOptions {
  external String? get space;
}

@JS()
@anonymous
class _ToGamutOptions {
  external String? get space;
  external String get method;
}

@JS()
@anonymous
class _InterpolationOptions {
  external double? get weight;
  external String? get method;
}
