// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'expression.dart';
import 'node.dart';

/// Plain text interpolated with Sass expressions.
class Interpolation implements SassNode {
  /// The contents of this interpolation.
  ///
  /// This contains [String]s and [Expression]s. It never contains two adjacent
  /// [String]s.
  final List<Object /* String | Expression */ > contents;

  final FileSpan span;

  /// If this contains no interpolated expressions, returns its text contents.
  ///
  /// Otherwise, returns `null`.
  String get asPlain {
    if (contents.isEmpty) return '';
    if (contents.length > 1) return null;
    var first = contents.first;
    return first is String ? first : null;
  }

  /// Returns the plain text before the interpolation, or the empty string.
  String get initialPlain {
    var first = contents.first;
    return first is String ? first : '';
  }

  Interpolation(Iterable<Object/*!*/ /* String | Expression */ > contents, this.span)
      : contents = List.unmodifiable(contents) {
    for (var i = 0; i < this.contents.length; i++) {
      if (this.contents[i] is! String && this.contents[i] is! Expression) {
        throw ArgumentError.value(this.contents, "contents",
            "May only contains Strings or Expressions.");
      }

      if (i != 0 &&
          this.contents[i - 1] is String &&
          this.contents[i] is String) {
        throw ArgumentError.value(
            this.contents, "contents", "May not contain adjacent Strings.");
      }
    }
  }

  String toString() =>
      contents.map((value) => value is String ? value : "#{$value}").join();
}
