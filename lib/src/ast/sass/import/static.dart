// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../import.dart';
import '../interpolation.dart';
import '../supports_condition.dart';

/// An import that produces a plain CSS `@import` rule.
///
/// {@category AST}
@sealed
class StaticImport implements Import {
  /// The URL for this import.
  ///
  /// This already contains quotes.
  final Interpolation url;

  /// The layer attached to this import, or `null` if no condition
  /// is attached.
  final Interpolation? layer;

  /// The supports condition attached to this import, or `null` if no condition
  /// is attached.
  final SupportsCondition? supports;

  /// The media query attached to this import, or `null` if no condition is
  /// attached.
  final Interpolation? media;

  final FileSpan span;

  StaticImport(this.url, this.span, {this.layer, this.supports, this.media});

  String toString() {
    var buffer = StringBuffer(url);
    if (layer != null) buffer.write(" $layer");
    if (supports != null) buffer.write(" supports($supports)");
    if (media != null) buffer.write(" $media");
    buffer.writeCharCode($semicolon);
    return buffer.toString();
  }
}
