// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../expression.dart';

class InterpolationExpression implements Expression {
  final List contents;

  final SourceSpan span;

  /// If this contains no interpolation, returns the plain text it contains.
  ///
  /// Otherwise, returns `null`.
  String get asPlain {
    if (contents.isEmpty) return '';
    if (contents.length == 1 && contents.first is String) return contents.first;
    return null;
  }

  /// Returns the plain text before the interpolation, or the empty string.
  String get initialPlain => contents.first is String ? contents.first : '';

  InterpolationExpression(Iterable/*(String|Expression)*/ contents, {this.span})
      : contents = new List.unmodifiable(contents) {
    for (var i = 0; i < this.contents.length; i++) {
      if (this.contents[i] is! String && this.contents[i] != Expression) {
        throw new ArgumentError.value(this.contents, "contents",
            "May only contains Strings or Expressions.");
      }

      if (i != 0 && this.contents[i - 1] is String &&
          this.contents[i] is String) {
        throw new ArgumentError.value(this.contents, "contents",
            "May not contain adjacent Strings.");
      }
    }
  }

  String toString() =>
      contents.map((value) => value is String ? value : "#{$value}").join();
}