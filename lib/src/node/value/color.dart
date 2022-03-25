// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../util/nullable.dart';
import '../../util/number.dart';
import '../../value.dart';
import '../reflection.dart';

/// The JavaScript `SassColor` class.
final JSClass colorClass = () {
  var jsClass = createJSClass('sass.SassColor', (Object self, _Channels color) {
    if (color.red != null) {
      return SassColor.rgb(fuzzyRound(color.red!), fuzzyRound(color.green!),
          fuzzyRound(color.blue!), color.alpha);
    } else if (color.saturation != null) {
      return SassColor.hsl(
          color.hue!, color.saturation!, color.lightness!, color.alpha);
    } else {
      return SassColor.hwb(
          color.hue!, color.whiteness!, color.blackness!, color.alpha);
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
      return self.changeRgb(
          red: options.red.andThen(fuzzyRound) ?? self.red,
          green: options.green.andThen(fuzzyRound) ?? self.green,
          blue: options.blue.andThen(fuzzyRound) ?? self.blue,
          alpha: options.alpha ?? self.alpha);
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

@JS()
@anonymous
class _Channels {
  external num? get red;
  external num? get green;
  external num? get blue;
  external num? get hue;
  external num? get saturation;
  external num? get lightness;
  external num? get whiteness;
  external num? get blackness;
  external num? get alpha;
}
