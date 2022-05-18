// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../import.dart';
import '../interpolation.dart';

/// An import that produces a plain CSS `@import` rule.
///
/// {@category AST}
@sealed
class StaticImport implements Import {
  /// The URL for this import.
  ///
  /// This already contains quotes.
  final Interpolation url;

  /// The modifiers (such as media or supports queries) attached to this import,
  /// or `null` if none are attached.
  final Interpolation? modifiers;

  final FileSpan span;

  StaticImport(this.url, this.span, {this.modifiers});

  String toString() => "$url${modifiers == null ? '' : ' $modifiers'}";
}
