// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:sass/src/js/immutable.dart';

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

  jsClass.defineMethod('change',
      (SassColor self, _ConstructionOptions options) {
    String initialSpace = self.space.name;
    ColorSpace initialSpaceClass = self.space;

    bool spaceSetExplicitly = options.space != null;
    String space = spaceSetExplicitly ? options.space! : initialSpace;

    Map<String, double?> changes = _changedOptions(options);
    var keys = changes.keys;

    if (self.isLegacy && !spaceSetExplicitly) {
      if (keys.contains('whiteness') || keys.contains('blackness')) {
        space = 'hwb';
      } else if (keys.contains('hue') ||
          keys.contains('saturation') ||
          keys.contains('lightness')) {
        space = 'hsl';
      } else if (keys.contains('red')) {
        space = 'rgb';
      }
      if (space != initialSpace) {
        // @todo emit a deprecation warning named `color-4-api`.
      }
    }

    var spaceClass = ColorSpace.fromName(space);
    var components =
        spaceClass.channels.map((channel) => channel.name).toList();
    components.add('alpha');

    for (final key in keys) {
      if (!components.contains(key)) {
        jsThrow(JsError("`$key` is not a valid channel in `$space`."));
      }
    }
    SassColor color = self.toSpace(spaceClass);

    SassColor changedColor;

    changedValue(String channel) {
      return _changeComponentValue(color, channel, changes);
    }

    switch (spaceClass) {
      case ColorSpace.hsl:
        if (!spaceSetExplicitly) {
          if ((keys.contains('hue') && changes['hue'] == null) ||
              (keys.contains('saturation') && changes['saturation'] == null) ||
              (keys.contains('lightness') && changes['lightness'] == null) ||
              (keys.contains('alpha') && changes['alpha'] == null)) {
            // @todo emit deprecation `null-alpha`
          }
          changedColor = SassColor.forSpaceInternal(
              spaceClass,
              changes['hue'] ?? color.channel('hue'),
              changes['saturation'] ?? color.channel('saturation'),
              changes['lightness'] ?? color.channel('lightness'),
              changes['alpha'] ?? color.channel('alpha'));
        } else {
          changedColor = SassColor.forSpaceInternal(
              spaceClass,
              changedValue('hue'),
              changedValue('saturation'),
              changedValue('lightness'),
              changedValue('alpha'));
        }
        break;

      case ColorSpace.hwb:
        if (!spaceSetExplicitly) {
          if ((keys.contains('hue') && changes['hue'] == null) ||
              (keys.contains('whiteness') && changes['whiteness'] == null) ||
              (keys.contains('blackness') && changes['blackness'] == null) ||
              (keys.contains('alpha') && changes['alpha'] == null)) {
            // @todo emit deprecation `null-alpha`
          }
          changedColor = SassColor.forSpaceInternal(
              spaceClass,
              options.hue ?? color.channel('hue'),
              options.whiteness ?? color.channel('whiteness'),
              options.blackness ?? color.channel('blackness'),
              options.alpha ?? color.channel('alpha'));
        } else {
          changedColor = SassColor.forSpaceInternal(
              spaceClass,
              changedValue('hue'),
              changedValue('whiteness'),
              changedValue('blackness'),
              changedValue('alpha'));
        }
        break;

      case ColorSpace.rgb:
        if (!spaceSetExplicitly) {
          if ((keys.contains('red') && changes['red'] == null) ||
              (keys.contains('green') && changes['green'] == null) ||
              (keys.contains('blue') && changes['blue'] == null) ||
              (keys.contains('alpha') && changes['alpha'] == null)) {
            // @todo emit deprecation `null-alpha`
          }
          changedColor = SassColor.forSpaceInternal(
              spaceClass,
              options.red ?? color.channel('red'),
              options.green ?? color.channel('green'),
              options.blue ?? color.channel('blue'),
              options.alpha ?? color.channel('alpha'));
        } else {
          changedColor = SassColor.forSpaceInternal(
              spaceClass,
              changedValue('red'),
              changedValue('green'),
              changedValue('blue'),
              changedValue('alpha'));
        }
        break;

      case ColorSpace.lab:
      case ColorSpace.oklab:
        changedColor = SassColor.forSpaceInternal(
            spaceClass,
            changedValue('lightness'),
            changedValue('a'),
            changedValue('b'),
            changedValue('alpha'));
        break;

      case ColorSpace.lch:
      case ColorSpace.oklch:
        changedColor = SassColor.forSpaceInternal(
            spaceClass,
            changedValue('lightness'),
            changedValue('chroma'),
            changedValue('hue'),
            changedValue('alpha'));
        break;

      case ColorSpace.a98Rgb:
      case ColorSpace.displayP3:
      case ColorSpace.prophotoRgb:
      case ColorSpace.srgb:
      case ColorSpace.srgbLinear:
        changedColor = SassColor.forSpaceInternal(
            spaceClass,
            changedValue('red'),
            changedValue('green'),
            changedValue('blue'),
            changedValue('alpha'));
        break;

      case ColorSpace.xyzD50:
      case ColorSpace.xyzD65:
        changedColor = SassColor.forSpaceInternal(spaceClass, changedValue('x'),
            changedValue('y'), changedValue('z'), changedValue('alpha'));
        break;

      default:
        throw "No space set";
    }

    return changedColor.toSpace(initialSpaceClass);
  });

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
  });

  jsClass.defineGetter('alpha', (SassColor self) => self.alpha);

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

  jsClass.defineMethod('isInGamut', (SassColor self, [String? space]) {
    String spaceName = space ?? self.space.name;
    ColorSpace spaceClass = ColorSpace.fromName(spaceName);
    SassColor color = self.toSpace(spaceClass);
    return color.isInGamut;
  });

  jsClass.defineMethod('toGamut', (SassColor self, [String? space]) {
    String spaceName = space ?? self.space.name;
    ColorSpace spaceClass = ColorSpace.fromName(spaceName);
    SassColor color = self.toSpace(spaceClass);
    return color.toGamut();
  });

  jsClass.defineGetter(
      'channelsOrNull', (SassColor self) => ImmutableList(self.channelsOrNull));

  jsClass.defineGetter('channels', (SassColor self) {
    final channelsOrNull = self.channelsOrNull;
    var channels = <num>[];
    for (final channel in channelsOrNull) {
      final value = channel ?? 0;
      channels.add(value);
    }
    return ImmutableList(channels);
  });

  jsClass.defineMethod('channel', (SassColor self, String channel,
      [ChannelOptions? options]) {
    String initialSpace = self.space.name;
    String space = options?.space ?? initialSpace;
    ColorSpace spaceClass = ColorSpace.fromName(space);

    SassColor color = self.toSpace(spaceClass);

    return color.channel(channel);
  });

  jsClass.defineMethod('isChannelMissing',
      (SassColor self, String channel) => self.isChannelMissing(channel));

  jsClass.defineGetter(
      'isAlphaMissing', (SassColor self) => self.isChannelMissing('alpha'));

  jsClass.defineMethod('isChannelPowerless', (SassColor self, String channel,
      [ChannelOptions? options]) {
    String initialSpace = self.space.name;
    String space = options?.space ?? initialSpace;
    ColorSpace spaceClass = ColorSpace.fromName(space);

    SassColor color = self.toSpace(spaceClass);

    return color.isChannelPowerless(channel);
  });

  jsClass.defineMethod('interpolate',
      (SassColor self, InterpolationOptions options) {
    InterpolationMethod interpolationMethod;

    if (options.method != null) {
      HueInterpolationMethod hue =
          HueInterpolationMethod.values.byName(options.method!);
      interpolationMethod = InterpolationMethod(self.space, hue);
    } else if (!self.space.isPolar) {
      interpolationMethod = InterpolationMethod(self.space);
    } else {
      interpolationMethod =
          InterpolationMethod(self.space, HueInterpolationMethod.shorter);
    }

    return self.interpolate(options.color2, interpolationMethod,
        weight: options.weight);
  });

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
/// `initial`.
double? _changeComponentValue(
    SassColor initial, String channel, Map<String, double?> changes) {
  var initialValue = initial.channel(channel);
  if (!changes.containsKey(channel)) {
    return initialValue;
  }
  return changes[channel];
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

Map<String, double?> _changedOptions(_ConstructionOptions options) {
  return {
    if (hasProperty(options, 'red')) 'red': options.red,
    if (hasProperty(options, 'green')) 'green': options.green,
    if (hasProperty(options, 'blue')) 'blue': options.blue,
    if (hasProperty(options, 'hue')) 'hue': options.hue,
    if (hasProperty(options, 'saturation')) 'saturation': options.saturation,
    if (hasProperty(options, 'lightness')) 'lightness': options.lightness,
    if (hasProperty(options, 'whiteness')) 'whiteness': options.whiteness,
    if (hasProperty(options, 'blackness')) 'blackness': options.blackness,
    if (hasProperty(options, 'alpha')) 'alpha': options.alpha,
    if (hasProperty(options, 'a')) 'a': options.a,
    if (hasProperty(options, 'b')) 'b': options.b,
    if (hasProperty(options, 'x')) 'x': options.x,
    if (hasProperty(options, 'y')) 'y': options.y,
    if (hasProperty(options, 'z')) 'z': options.z,
    if (hasProperty(options, 'chroma')) 'chroma': options.chroma,
  };
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
  external SassColor color2;
  external double? weight;
  external String? method;
}
