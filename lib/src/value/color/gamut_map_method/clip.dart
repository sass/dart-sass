// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../color.dart';

/// Gamut mapping by clipping individual channels.
///
/// @nodoc
@internal
final class ClipGamutMap extends GamutMapMethod {
  const ClipGamutMap() : super("clip");

  SassColor map(SassColor color) => SassColor.forSpaceInternal(
      color.space,
      _clampChannel(color.channel0OrNull, color.space.channels[0]),
      _clampChannel(color.channel1OrNull, color.space.channels[1]),
      _clampChannel(color.channel2OrNull, color.space.channels[2]),
      color.alphaOrNull);

  /// Clamps the channel value [value] within the bounds given by [channel].
  double? _clampChannel(double? value, ColorChannel channel) => value == null
      ? null
      : switch (channel) {
          LinearChannel(:var min, :var max) => value.clamp(min, max),
          _ => value
        };
}
