// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../util/number.dart';
import '../../color.dart';

/// Gamut mapping using the deltaEOK difference formula and the local-MINDE
/// improvement.
///
/// @nodoc
@internal
final class LocalMindeGamutMap extends GamutMapMethod {
  /// A constant from the gamut-mapping algorithm.
  static const _jnd = 0.02;

  /// A constant from the gamut-mapping algorithm.
  static const _epsilon = 0.0001;

  const LocalMindeGamutMap() : super("local-minde");

  SassColor map(SassColor color) {
    // Algorithm from https://www.w3.org/TR/2022/CRD-css-color-4-20221101/#css-gamut-mapping-algorithm
    var originOklch = color.toSpace(ColorSpace.oklch);

    // The channel equivalents to `current` in the Color 4 algorithm.
    var lightness = originOklch.channel0OrNull;
    var hue = originOklch.channel2OrNull;
    var alpha = originOklch.alphaOrNull;

    if (fuzzyGreaterThanOrEquals(lightness ?? 0, 1)) {
      return color.isLegacy
          ? SassColor.rgb(255, 255, 255, color.alphaOrNull).toSpace(color.space)
          : SassColor.forSpaceInternal(color.space, 1, 1, 1, color.alphaOrNull);
    } else if (fuzzyLessThanOrEquals(lightness ?? 0, 0)) {
      return SassColor.rgb(0, 0, 0, color.alphaOrNull).toSpace(color.space);
    }

    var clipped = color.toGamut(GamutMapMethod.clip);
    if (_deltaEOK(clipped, color) < _jnd) return clipped;

    var min = 0.0;
    var max = originOklch.channel1;
    var minInGamut = true;
    while (max - min > _epsilon) {
      var chroma = (min + max) / 2;

      // In the Color 4 algorithm `current` is in Oklch, but all its actual uses
      // other than modifying chroma convert it to `color.space` first so we
      // just store it in that space to begin with.
      var current =
          ColorSpace.oklch.convert(color.space, lightness, chroma, hue, alpha);

      // Per [this comment], the intention of the algorithm is to fall through
      // this clause if `minInGamut = false` without checking
      // `current.isInGamut` at all, even though that's unclear from the
      // pseudocode. `minInGamut = false` *should* imply `current.isInGamut =
      // false`.
      //
      // [this comment]: https://github.com/w3c/csswg-drafts/issues/10226#issuecomment-2065534713
      if (minInGamut && current.isInGamut) {
        min = chroma;
        continue;
      }

      clipped = current.toGamut(GamutMapMethod.clip);
      var e = _deltaEOK(clipped, current);
      if (e < _jnd) {
        if (_jnd - e < _epsilon) return clipped;
        minInGamut = false;
        min = chroma;
      } else {
        max = chroma;
      }
    }
    return clipped;
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
}
