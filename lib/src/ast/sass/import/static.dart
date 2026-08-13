// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../import.dart';
import '../interpolation.dart';

/// An import that produces a plain CSS `@import` rule.
///
/// {@category AST}
final class StaticImport(
  /// The URL for this import.
  ///
  /// This already contains quotes.
  final Interpolation url,
  @override final FileSpan span, {

  /// The modifiers (such as media or supports queries) attached to this import,
  /// or `null` if none are attached.
  final Interpolation? modifiers,
}) implements Import {
  @override
  String toString() => "$url${modifiers == null ? '' : ' $modifiers'}";
}
