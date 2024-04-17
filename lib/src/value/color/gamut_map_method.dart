// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../exception.dart';
import '../color.dart';
import 'gamut_map_method/clip.dart';
import 'gamut_map_method/local_minde.dart';

/// Different algorithms that can be used to map an out-of-gamut Sass color into
/// the gamut for its color space.
///
/// {@category Value}
@sealed
abstract base class GamutMapMethod {
  /// Clamp each color channel that's outside the gamut to the minimum or
  /// maximum value for that channel.
  ///
  /// This algorithm will produce poor visual results, but it may be useful to
  /// match the behavior of other situations in which a color can be clipped.
  static const GamutMapMethod clip = ClipGamutMap();

  /// The algorithm specified in [the original Color Level 4 candidate
  /// recommendation].
  ///
  /// This maps in the Oklch color space, using the [deltaEOK] color difference
  /// formula and the [local-MINDE] improvement.
  ///
  /// [the original Color Level 4 candidate recommendation]: https://www.w3.org/TR/2024/CRD-css-color-4-20240213/#css-gamut-mapping
  /// [the original Color Level 4 candidate recommendation]: https://www.w3.org/TR/2024/CRD-css-color-4-20240213/#color-difference-OK
  /// [local-MINDE]: https://www.w3.org/TR/2024/CRD-css-color-4-20240213/#GM-chroma-local-MINDE
  static const GamutMapMethod localMinde = LocalMindeGamutMap();

  /// The Sass name of the gamut-mapping algorithm.
  final String name;

  /// @nodoc
  @internal
  const GamutMapMethod(this.name);

  /// Parses a [GamutMapMethod] from its Sass name.
  ///
  /// Throws a [SassScriptException] if there is no method with the given
  /// [name]. If this came from a function argument, [argumentName] is the
  /// argument name (without the `$`). This is used for error reporting.
  factory GamutMapMethod.fromName(String name, [String? argumentName]) =>
      switch (name) {
        'clip' => GamutMapMethod.clip,
        'local-minde' => GamutMapMethod.localMinde,
        _ => throw SassScriptException(
            'Unknown gamut map method "$name".', argumentName)
      };

  /// Maps [color] to its gamut using this method's algorithm.
  ///
  /// Callers should use [SassColor.toGamut] instead of this method.
  ///
  /// @nodoc
  @internal
  SassColor map(SassColor color);

  String toString() => name;
}
