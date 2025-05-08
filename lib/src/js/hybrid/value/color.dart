// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../deprecation.dart';
import '../../../evaluation_context.dart';
import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

extension type JSSassColor._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSSassColor> jsClass = () {
    var jsClass = JSClass<JSSassColor>('sass.SassColor', (JSColor self, _ConstructionOptions options) {

// If alpha is explicitly null and space is not set, emit a deprecation.
void _checkNullAlphaDeprecation(_ConstructionOptions options) {
  if (options.alpha.isNull && options.space == null) {
    _emitNullAlphaDeprecation();
  }
}

    var constructionSpace = _constructionSpace(options);
    switch (constructionSpace) {
      case ColorSpace.rgb:
        _checkNullAlphaDeprecation(options);
        return SassColor.rgb(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );

      case ColorSpace.hsl:
        _checkNullAlphaDeprecation(options);
        return SassColor.hsl(
          options.hue,
          options.saturation,
          options.lightness,
          options.alphaOrDefault(() => 1),
        );

      case ColorSpace.hwb:
        _checkNullAlphaDeprecation(options);
        return SassColor.hwb(
          options.hue,
          options.whiteness,
          options.blackness,
          options.alphaOrDefault(() => 1),
        );

      case ColorSpace.lab:
        return SassColor.lab(
          options.lightness,
          options.a,
          options.b,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.oklab:
        return SassColor.oklab(
          options.lightness,
          options.a,
          options.b,
          options.alphaOrDefault(() => 1),
        );

      case ColorSpace.lch:
        return SassColor.lch(
          options.lightness,
          options.chroma,
          options.hue,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.oklch:
        return SassColor.oklch(
          options.lightness,
          options.chroma,
          options.hue,
          options.alphaOrDefault(() => 1),
        );

      case ColorSpace.srgb:
        return SassColor.srgb(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.srgbLinear:
        return SassColor.srgbLinear(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.displayP3:
        return SassColor.displayP3(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.a98Rgb:
        return SassColor.a98Rgb(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.prophotoRgb:
        return SassColor.prophotoRgb(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.rec2020:
        return SassColor.rec2020(
          options.red,
          options.green,
          options.blue,
          options.alphaOrDefault(() => 1),
        );

      // `xyz` name is mapped to `xyzD65` space.
      case ColorSpace.xyzD50:
        return SassColor.xyzD50(
          options.x,
          options.y,
          options.z,
          options.alphaOrDefault(() => 1),
        );
      case ColorSpace.xyzD65:
        return SassColor.xyzD65(
          options.x,
          options.y,
          options.z,
          options.alphaOrDefault(() => 1),
        );

      default:
        throw "Unreachable";
    }
  }.toJS)..defineStaticMethods({
    'equals': ((JSJSSassColor self, JSAny? other) => self.toDart == other).toJS,
    'hashCode': ((JSJSSassColor self) => self.toDart.hashCode).toJS,
    'toSpace': ((JSJSSassColor self, String space) => self.toSpace(space).toJS).toJS,
    'isInGamut': ((JSJSSassColor self, [String? space]) =>
        self.toSpace(space).isInGamut).toJS,
    'toGamut': ((JSSassColor self, _ToGamutOptions options) =>
      self.toSpace(options.space).toGamut(GamutMapMethod.fromName(options.method)).toSpace(self.toDart.space).toJS).toJS,
    'channel': ((JSSassColor self, String channel, [_ChannelOptions? options]) =>
        self.toSpace(options?.space).channel(channel)).toJS,
    'isChannelMissing': ((JSSassColor self, String channel) =>
        self.toDart.isChannelMissing(channel)).toJS,
    'isChannelPowerless': ((JSSassColor self, String channel,
            [_ChannelOptions? options]) =>
        self.toSpace(options?.space).isChannelPowerless(channel)).toJS,
    'change': ((JSSassColor jsSelf, _ConstructionOptions options) {
      var self = jsSelf.toDart;
      var spaceSetExplicitly = options.space != null;
      var space =
          spaceSetExplicitly ? ColorSpace.fromName(options.space!) : self.space;

      if (self.isLegacy && !spaceSetExplicitly) {
        if (options.hasProperty('whiteness'.toJS) ||
            options.hasProperty('blackness'.toJS)) {
          space = ColorSpace.hwb;
        } else if (options.hasProperty('hue'.toJS) &&
            self.space == ColorSpace.hwb) {
          space = ColorSpace.hwb;
        } else if (options.hasProperty('hue'.toJS) ||
            options.hasProperty('saturation'.toJS) ||
            options.hasProperty('lightness'.toJS)) {
          space = ColorSpace.hsl;
        } else if (options.hasProperty('red'.toJS) ||
            options.hasProperty('green'.toJS) ||
            options.hasProperty('blue'.toJS)) {
          space = ColorSpace.rgb;
        }
        if (space != self.space) {
          warnForDeprecationFromApi(
            "Changing a channel not in this color's space without explicitly specifying "
            "the `space` option is deprecated."
            "\n"
            "More info: https://sass-lang.com/d/color-4-api",
            Deprecation.color4Api,
          );
        }
      }

      for (final jsKey in options.keys) {
        var key = jsKey.toDart;
        if (['alpha', 'space'].contains(key)) continue;
        if (!space.channels.any((channel) => channel.name == key)) {
          JSError.throwLikeJS(
              JSError("`$key` is not a valid channel in `$space`."));
        }
      }

      var color = self.toSpace(space);

      JSSassColor changedColor;

      double? changedValue(String channel) {
        return _changeComponentValue(color, channel, options);
      }

      switch (space) {
        case ColorSpace.hsl when spaceSetExplicitly:
          changedColor = JSSassColor.hsl(
            changedValue('hue'),
            changedValue('saturation'),
            changedValue('lightness'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.hsl:
          if (options.hue.isNull) {
            _emitColor4ApiNullDeprecation('hue');
          } else if (options.saturation.isNull) {
            _emitColor4ApiNullDeprecation('saturation');
          } else if (options.lightness.isNull) {
            _emitColor4ApiNullDeprecation('lightness');
          }
          if (options.alpha.isNull) {
            _emitNullAlphaDeprecation();
          }
          changedColor = JSSassColor.hsl(
            options.hue ?? color.channel('hue'),
            options.saturation ?? color.channel('saturation'),
            options.lightness ?? color.channel('lightness'),
            options.alpha ?? color.channel('alpha'),
          );
          break;

        case ColorSpace.hwb when spaceSetExplicitly:
          changedColor = JSSassColor.hwb(
            changedValue('hue'),
            changedValue('whiteness'),
            changedValue('blackness'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.hwb:
          if (options.hue.isNull) {
            _emitColor4ApiNullDeprecation('hue');
          } else if (options.whiteness.isNull) {
            _emitColor4ApiNullDeprecation('whiteness');
          } else if (options.blackness.isNull) {
            _emitColor4ApiNullDeprecation('blackness');
          }
          if (options.alpha.isNull) _emitNullAlphaDeprecation();
          changedColor = JSSassColor.hwb(
            options.hue ?? color.channel('hue'),
            options.whiteness ?? color.channel('whiteness'),
            options.blackness ?? color.channel('blackness'),
            options.alpha ?? color.channel('alpha'),
          );

          break;

        case ColorSpace.rgb when spaceSetExplicitly:
          changedColor = JSSassColor.rgb(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.rgb:
          if (options.red.isNull) {
            _emitColor4ApiNullDeprecation('red');
          } else if (options.green.isNull) {
            _emitColor4ApiNullDeprecation('green');
          } else if (options.blue.isNull) {
            _emitColor4ApiNullDeprecation('blue');
          }
          if (options.alpha.isNull) {
            _emitNullAlphaDeprecation();
          }
          changedColor = JSSassColor.rgb(
            options.red ?? color.channel('red'),
            options.green ?? color.channel('green'),
            options.blue ?? color.channel('blue'),
            options.alpha ?? color.channel('alpha'),
          );
          break;

        case ColorSpace.lab:
          changedColor = JSSassColor.lab(
            changedValue('lightness'),
            changedValue('a'),
            changedValue('b'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.oklab:
          changedColor = JSSassColor.oklab(
            changedValue('lightness'),
            changedValue('a'),
            changedValue('b'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.lch:
          changedColor = JSSassColor.lch(
            changedValue('lightness'),
            changedValue('chroma'),
            changedValue('hue'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.oklch:
          changedColor = JSSassColor.oklch(
            changedValue('lightness'),
            changedValue('chroma'),
            changedValue('hue'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.a98Rgb:
          changedColor = JSSassColor.a98Rgb(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.displayP3:
          changedColor = JSSassColor.displayP3(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.prophotoRgb:
          changedColor = JSSassColor.prophotoRgb(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.rec2020:
          changedColor = JSSassColor.rec2020(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.srgb:
          changedColor = JSSassColor.srgb(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.srgbLinear:
          changedColor = JSSassColor.srgbLinear(
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'),
          );
          break;

        case ColorSpace.xyzD50:
          changedColor = JSSassColor.forSpaceInternal(
            space,
            changedValue('x'),
            changedValue('y'),
            changedValue('z'),
            changedValue('alpha'),
          );
          break;
        case ColorSpace.xyzD65:
          changedColor = JSSassColor.forSpaceInternal(
            space,
            changedValue('x'),
            changedValue('y'),
            changedValue('z'),
            changedValue('alpha'),
          );
          break;

        default:
          throw "No space set";
      }

      return changedColor.toSpace(self.space).toJS;
    }).toJS,
    'interpolate': ((
      JSSassColor self,
      JSSassColor color2, [
      _InterpolationOptions? options,
    ]) {
      InterpolationMethod interpolationMethod;

      if (options?.method case var method?) {
        var hue = HueInterpolationMethod.values.byName(method);
        interpolationMethod = InterpolationMethod(self.toDart.space, hue);
      } else if (!self.space.isPolar) {
        interpolationMethod = InterpolationMethod(self.toDart.space);
      } else {
        interpolationMethod = InterpolationMethod(
          self.toDart.space,
          HueInterpolationMethod.shorter,
        );
      }

      return self.toDart.interpolate(
        color2,
        interpolationMethod,
        weight: options?.weight,
      ).toJS;
    }).toJS,
  })..defineGetters({
    'red': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('red');
      return self.toDart.red;
    }).toJS,
    'green': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('green');
      return self.toDart.green;
    }).toJS,
    'blue': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('blue');
      return self.toDart.blue;
    }).toJS,
    'hue': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('hue');
      return self.toDart.hue;
    }).toJS,
    'saturation': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('saturation');
      return self.toDart.saturation;
    }).toJS,
    'lightness': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('lightness');
      return self.toDart.lightness;
    }).toJS,
    'whiteness': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('whiteness');
      return self.toDart.whiteness;
    }).toJS,
    'blackness': ((JSSassColor self) {
      _emitColor4ApiChannelDeprecation('blackness');
      return self.toDart.blackness;
    }).toJS,
    'alpha': ((JSSassColor self) => self.toDart.alpha).toJS,
    'space': ((JSSassColor self) => self.toDart.space.name).toJS,
    'isLegacy': ((JSSassColor self) => self.toDart.isLegacy).toJS,
    'channelsOrNull': ((JSSassColor self) => self.toDart.channelsOrNull.toJSImmutable).toJS,
    'channels': ((JSSassColor self) => self.channels.toJSImmutable).toJS,
  });

  SassColor.rgb(0, 0, 0).toJS.constructor.injectSuperclass(jsClass);

  return jsClass;
}();

  // Return a SassColor in a named space, or in its original space.
  SassColor toSpace(String? space) =>
  space == null ? toDart : 
    toDart.toSpace(ColorSpace.fromName(space));

  SassColor get toDart => this as SassColor;
}

/// This procedure takes a `channel` name, an object `changes` and a SassColor
/// `initial` and returns the result of applying the change for `channel` to
/// `initial`.
double? _changeComponentValue(
  SassColor initial,
  String channel,
  _ConstructionOptions changes,
) =>
    changes.hasProperty(channel.toJS) && !changes[channel].isUndefined
        ? changes[channel]
        : initial.channel(channel);

/// Determines the construction space based on the provided options.
ColorSpace _constructionSpace(_ConstructionOptions options) {
  if (options.space case var space?) return ColorSpace.fromName(space);
  if (options.red != null) return ColorSpace.rgb;
  if (options.saturation != null) return ColorSpace.hsl;
  if (options.whiteness != null) return ColorSpace.hwb;
  throw "No color space found";
}

// Warn users about null-alpha deprecation.
void _emitNullAlphaDeprecation() {
  warnForDeprecationFromApi(
    "Passing `alpha: null` without setting `space` is deprecated."
    "\n"
    "More info: https://sass-lang.com/d/null-alpha",
    Deprecation.nullAlpha,
  );
}

// Warn users about `null` channel values without setting `space`.
void _emitColor4ApiNullDeprecation(String name) {
  warnForDeprecationFromApi(
    "Passing `$name: null` without setting `space` is deprecated."
    "\n"
    "More info: https://sass-lang.com/d/color-4-api",
    Deprecation.color4Api,
  );
}

// Warn users about legacy color channel getters.
void _emitColor4ApiChannelDeprecation(String name) {
  warnForDeprecationFromApi(
    "$name is deprecated, use `channel` instead."
    "\n"
    "More info: https://sass-lang.com/d/color-4-api",
    Deprecation.color4Api,
  );
}

extension SassColorToJS on SassColor {
  JSSassColor get toJS => this as JSSassColor;
}

@anonymous
extension type _ConstructionOptions._(_Channels _) implements _Channels {
  external String? get space;
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

  /// Returns [alpha], but with an `undefined` value replaced with the result of
  /// [defaultCallback].
  ///
  /// This ensures that an explicitly null alpha remains null so it can
  /// represent a missing value.
  double? alphaOrDefault(double Function() defaultCallback) => alpha.isUndefined ? defaultCallback() : alpha;
}

@anonymous
extension type _ChannelOptions._(JSObject _) implements JSObject {
  external String? get space;
}

@anonymous
extension type _ToGamutOptions._(JSObject _) implements JSObject {
  external String? get space;
  external String get method;
}

@anonymous
extension class _InterpolationOptions._(JSObject _) implements JSObject {
  external double? get weight;
  external String? get method;
}
