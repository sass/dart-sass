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
      (Object self, _ConstructionOptions color) {
    var constructionSpace = _constructionSpace(color);
    switch (constructionSpace) {
      case ColorSpace.rgb:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.red),
            parseChannelValue(color.green),
            parseChannelValue(color.blue),
            _handleUndefinedAlpha(color.alpha));
      case ColorSpace.hsl:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.hue),
            parseChannelValue(color.saturation),
            parseChannelValue(color.lightness),
            _handleUndefinedAlpha(color.alpha));
      case ColorSpace.hwb:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.hue),
            parseChannelValue(color.whiteness),
            parseChannelValue(color.blackness),
            _handleUndefinedAlpha(color.alpha));
      case ColorSpace.lab:
      case ColorSpace.oklab:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.lightness),
            parseChannelValue(color.a),
            parseChannelValue(color.b),
            _handleUndefinedAlpha(color.alpha));
      case ColorSpace.lch:
      case ColorSpace.oklch:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.lightness),
            parseChannelValue(color.chroma),
            parseChannelValue(color.hue),
            _handleUndefinedAlpha(color.alpha));
      case ColorSpace.srgb:
      case ColorSpace.srgbLinear:
      case ColorSpace.displayP3:
      case ColorSpace.a98Rgb:
      case ColorSpace.prophotoRgb:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.red),
            parseChannelValue(color.green),
            parseChannelValue(color.blue),
            _handleUndefinedAlpha(color.alpha));
      // @todo: xyz space is in spec, but not implemented
      // case ColorSpace.xyz:
      case ColorSpace.xyzD50:
      case ColorSpace.xyzD65:
        return SassColor.forSpaceInternal(
            constructionSpace,
            parseChannelValue(color.x),
            parseChannelValue(color.y),
            parseChannelValue(color.z),
            _handleUndefinedAlpha(color.alpha));
      default:
        throw "Unreachable";
    }
  });

  jsClass.defineMethod('change', (SassColor self, _Channels options) {
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
  });

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
double? parseChannelValue(double? value) => value;

/// Determines the construction space based on the provided options.
ColorSpace _constructionSpace(_ConstructionOptions options) {
  if (options.space != null) return ColorSpace.fromName(options.space!);
  if (options.red != null) return ColorSpace.rgb;
  if (options.saturation != null) return ColorSpace.hsl;
  if (options.whiteness != null) return ColorSpace.hwb;
  throw "No color space found";
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
