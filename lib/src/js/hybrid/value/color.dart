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
import '../../extension/class.dart';
import '../../immutable.dart';

/// This procedure takes a `channel` name, an object `changes` and a SassColor
/// `initial` and returns the result of applying the change for `channel` to
/// `initial`.
double? _changeComponentValue(
  SassColor initial,
  String channel,
  _ConstructionOptions changes,
) {
  var value = changes.getProperty<JSNumber?>(channel.toJS);
  return value.isUndefined ? initial.channel(channel) : value?.toDartDouble;
}

/// Determines the construction space based on the provided options.
ColorSpace _constructionSpace(_ConstructionOptions options) {
  if (options.space case var space?) return ColorSpace.fromName(space);
  if (options.red != null) return ColorSpace.rgb;
  if (options.saturation != null) return ColorSpace.hsl;
  if (options.whiteness != null) return ColorSpace.hwb;
  throw "No color space found";
}

// If alpha is explicitly null and space is not set, emit a deprecation.
void _checkNullAlphaDeprecation(_ConstructionOptions options) {
  if (options.alpha.isNull && options.space == null) {
    _emitNullAlphaDeprecation();
  }
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
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassColor>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassColor>>(
        (_ConstructionOptions options) {
      var constructionSpace = _constructionSpace(options);
      switch (constructionSpace) {
        case ColorSpace.rgb:
          _checkNullAlphaDeprecation(options);
          return SassColor.rgb(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        case ColorSpace.hsl:
          _checkNullAlphaDeprecation(options);
          return SassColor.hsl(
            options.hue?.toDartDouble,
            options.saturation?.toDartDouble,
            options.lightness?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        case ColorSpace.hwb:
          _checkNullAlphaDeprecation(options);
          return SassColor.hwb(
            options.hue?.toDartDouble,
            options.whiteness?.toDartDouble,
            options.blackness?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        case ColorSpace.lab:
          return SassColor.lab(
            options.lightness?.toDartDouble,
            options.a?.toDartDouble,
            options.b?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.oklab:
          return SassColor.oklab(
            options.lightness?.toDartDouble,
            options.a?.toDartDouble,
            options.b?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        case ColorSpace.lch:
          return SassColor.lch(
            options.lightness?.toDartDouble,
            options.chroma?.toDartDouble,
            options.hue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.oklch:
          return SassColor.oklch(
            options.lightness?.toDartDouble,
            options.chroma?.toDartDouble,
            options.hue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        case ColorSpace.srgb:
          return SassColor.srgb(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.srgbLinear:
          return SassColor.srgbLinear(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.displayP3:
          return SassColor.displayP3(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.a98Rgb:
          return SassColor.a98Rgb(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.prophotoRgb:
          return SassColor.prophotoRgb(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.rec2020:
          return SassColor.rec2020(
            options.red?.toDartDouble,
            options.green?.toDartDouble,
            options.blue?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        // `xyz` name is mapped to `xyzD65` space.
        case ColorSpace.xyzD50:
          return SassColor.xyzD50(
            options.x?.toDartDouble,
            options.y?.toDartDouble,
            options.z?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;
        case ColorSpace.xyzD65:
          return SassColor.xyzD65(
            options.x?.toDartDouble,
            options.y?.toDartDouble,
            options.z?.toDartDouble,
            options.alphaOrDefault(() => 1),
          ).toJS;

        default:
          throw "Unreachable";
      }
    }.toJS)
      ..defineMethods({
        'equals': ((UnsafeDartWrapper<SassColor> self, JSAny? other) =>
            switch (other.asClassOrNull(SassColorToJS.jsClass)) {
              var color? => self.toDart == color.toDart,
              _ => false,
            }).toJSCaptureThis,
        'hashCode': ((UnsafeDartWrapper<SassColor> self) =>
            self.toDart.hashCode).toJSCaptureThis,
        'toSpace': ((UnsafeDartWrapper<SassColor> self, String space) =>
            self.toSpace(space).toJS).toJSCaptureThis,
        'isInGamut': ((UnsafeDartWrapper<SassColor> self, [String? space]) =>
            self.toSpace(space).isInGamut).toJSCaptureThis,
        'toGamut':
            ((UnsafeDartWrapper<SassColor> self, _ToGamutOptions options) =>
                self
                    .toSpace(options.space)
                    .toGamut(GamutMapMethod.fromName(options.method))
                    .toSpace(self.toDart.space)
                    .toJS).toJSCaptureThis,
        'channel': ((UnsafeDartWrapper<SassColor> self, String channel,
                [_ChannelOptions? options]) =>
            self.toSpace(options?.space).channel(channel)).toJSCaptureThis,
        'isChannelMissing':
            ((UnsafeDartWrapper<SassColor> self, String channel) =>
                self.toDart.isChannelMissing(channel)).toJSCaptureThis,
        'isChannelPowerless': ((UnsafeDartWrapper<SassColor> self,
                    String channel, [_ChannelOptions? options]) =>
                self.toSpace(options?.space).isChannelPowerless(channel))
            .toJSCaptureThis,
        'change': ((UnsafeDartWrapper<SassColor> jsSelf,
            _ConstructionOptions options) {
          var self = jsSelf.toDart;
          var spaceSetExplicitly = options.space != null;
          var space = spaceSetExplicitly
              ? ColorSpace.fromName(options.space!)
              : self.space;

          if (self.isLegacy && !spaceSetExplicitly) {
            if (options.hasProperty('whiteness'.toJS).toDart ||
                options.hasProperty('blackness'.toJS).toDart) {
              space = ColorSpace.hwb;
            } else if (options.hasProperty('hue'.toJS).toDart &&
                self.space == ColorSpace.hwb) {
              space = ColorSpace.hwb;
            } else if (options.hasProperty('hue'.toJS).toDart ||
                options.hasProperty('saturation'.toJS).toDart ||
                options.hasProperty('lightness'.toJS).toDart) {
              space = ColorSpace.hsl;
            } else if (options.hasProperty('red'.toJS).toDart ||
                options.hasProperty('green'.toJS).toDart ||
                options.hasProperty('blue'.toJS).toDart) {
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
              changedColor = SassColor.hsl(
                options.hue?.toDartDouble ?? color.channel('hue'),
                options.saturation?.toDartDouble ?? color.channel('saturation'),
                options.lightness?.toDartDouble ?? color.channel('lightness'),
                options.alpha?.toDartDouble ?? color.channel('alpha'),
              );
              break;

            case ColorSpace.hwb when spaceSetExplicitly:
              changedColor = SassColor.hwb(
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
              changedColor = SassColor.hwb(
                options.hue?.toDartDouble ?? color.channel('hue'),
                options.whiteness?.toDartDouble ?? color.channel('whiteness'),
                options.blackness?.toDartDouble ?? color.channel('blackness'),
                options.alpha?.toDartDouble ?? color.channel('alpha'),
              );

              break;

            case ColorSpace.rgb when spaceSetExplicitly:
              changedColor = SassColor.rgb(
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
              changedColor = SassColor.rgb(
                options.red?.toDartDouble ?? color.channel('red'),
                options.green?.toDartDouble ?? color.channel('green'),
                options.blue?.toDartDouble ?? color.channel('blue'),
                options.alpha?.toDartDouble ?? color.channel('alpha'),
              );
              break;

            case ColorSpace.lab:
              changedColor = SassColor.lab(
                changedValue('lightness'),
                changedValue('a'),
                changedValue('b'),
                changedValue('alpha'),
              );
              break;

            case ColorSpace.oklab:
              changedColor = SassColor.oklab(
                changedValue('lightness'),
                changedValue('a'),
                changedValue('b'),
                changedValue('alpha'),
              );
              break;

            case ColorSpace.lch:
              changedColor = SassColor.lch(
                changedValue('lightness'),
                changedValue('chroma'),
                changedValue('hue'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.oklch:
              changedColor = SassColor.oklch(
                changedValue('lightness'),
                changedValue('chroma'),
                changedValue('hue'),
                changedValue('alpha'),
              );
              break;

            case ColorSpace.a98Rgb:
              changedColor = SassColor.a98Rgb(
                changedValue('red'),
                changedValue('green'),
                changedValue('blue'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.displayP3:
              changedColor = SassColor.displayP3(
                changedValue('red'),
                changedValue('green'),
                changedValue('blue'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.prophotoRgb:
              changedColor = SassColor.prophotoRgb(
                changedValue('red'),
                changedValue('green'),
                changedValue('blue'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.rec2020:
              changedColor = SassColor.rec2020(
                changedValue('red'),
                changedValue('green'),
                changedValue('blue'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.srgb:
              changedColor = SassColor.srgb(
                changedValue('red'),
                changedValue('green'),
                changedValue('blue'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.srgbLinear:
              changedColor = SassColor.srgbLinear(
                changedValue('red'),
                changedValue('green'),
                changedValue('blue'),
                changedValue('alpha'),
              );
              break;

            case ColorSpace.xyzD50:
              changedColor = SassColor.forSpaceInternal(
                space,
                changedValue('x'),
                changedValue('y'),
                changedValue('z'),
                changedValue('alpha'),
              );
              break;
            case ColorSpace.xyzD65:
              changedColor = SassColor.forSpaceInternal(
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
        }).toJSCaptureThis,
        'interpolate': ((
          UnsafeDartWrapper<SassColor> self,
          UnsafeDartWrapper<SassColor> color2, [
          _InterpolationOptions? options,
        ]) {
          InterpolationMethod interpolationMethod;

          if (options?.method case var method?) {
            var hue = HueInterpolationMethod.values.byName(method);
            interpolationMethod = InterpolationMethod(self.toDart.space, hue);
          } else if (!self.toDart.space.isPolar) {
            interpolationMethod = InterpolationMethod(self.toDart.space);
          } else {
            interpolationMethod = InterpolationMethod(
              self.toDart.space,
              HueInterpolationMethod.shorter,
            );
          }

          return self.toDart
              .interpolate(
                color2.toDart,
                interpolationMethod,
                weight: options?.weight,
              )
              .toJS;
        }).toJSCaptureThis,
      })
      ..defineGetters({
        'red': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('red');
          return self.toDart.red.toJS;
        },
        'green': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('green');
          return self.toDart.green.toJS;
        },
        'blue': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('blue');
          return self.toDart.blue.toJS;
        },
        'hue': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('hue');
          return self.toDart.hue.toJS;
        },
        'saturation': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('saturation');
          return self.toDart.saturation.toJS;
        },
        'lightness': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('lightness');
          return self.toDart.lightness.toJS;
        },
        'whiteness': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('whiteness');
          return self.toDart.whiteness.toJS;
        },
        'blackness': (UnsafeDartWrapper<SassColor> self) {
          _emitColor4ApiChannelDeprecation('blackness');
          return self.toDart.blackness.toJS;
        },
        'alpha': (UnsafeDartWrapper<SassColor> self) => self.toDart.alpha.toJS,
        'space': (UnsafeDartWrapper<SassColor> self) =>
            self.toDart.space.name.toJS,
        'isLegacy': (UnsafeDartWrapper<SassColor> self) =>
            self.toDart.isLegacy.toJS,
        'channelsOrNull': (UnsafeDartWrapper<SassColor> self) =>
            (self.toDart.channelsOrNull as JSArray<JSNumber?>).toJSImmutable,
        'channels': (UnsafeDartWrapper<SassColor> self) =>
            (self.toDart.channels as JSArray<JSNumber>).toJSImmutable,
      });

    SassColor.rgb(0, 0, 0).toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassColor> get toJS => toUnsafeWrapper;
}

extension on UnsafeDartWrapper<SassColor> {
  // Return a SassColor in a named space, or in its original space.
  SassColor toSpace(String? space) =>
      space == null ? toDart : toDart.toSpace(ColorSpace.fromName(space));
}

extension type _ConstructionOptions._(JSObject _) implements JSObject {
  external String? get space;
  external JSNumber? get red;
  external JSNumber? get green;
  external JSNumber? get blue;
  external JSNumber? get hue;
  external JSNumber? get saturation;
  external JSNumber? get lightness;
  external JSNumber? get whiteness;
  external JSNumber? get blackness;
  external JSNumber? get alpha;
  external JSNumber? get a;
  external JSNumber? get b;
  external JSNumber? get x;
  external JSNumber? get y;
  external JSNumber? get z;
  external JSNumber? get chroma;

  /// Returns [alpha], but with an `undefined` value replaced with the result of
  /// [defaultCallback].
  ///
  /// This ensures that an explicitly null alpha remains null so it can
  /// represent a missing value.
  double? alphaOrDefault(double Function() defaultCallback) =>
      alpha.isUndefined ? defaultCallback() : alpha?.toDartDouble;
}

extension type _ChannelOptions._(JSObject _) implements JSObject {
  external String? get space;
}

extension type _ToGamutOptions._(JSObject _) implements JSObject {
  external String? get space;
  external String get method;
}

extension type _InterpolationOptions._(JSObject _) implements JSObject {
  external double? get weight;
  external String? get method;
}
