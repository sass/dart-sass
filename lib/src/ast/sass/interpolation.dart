// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import 'expression.dart';
import 'node.dart';

/// Plain text interpolated with Sass expressions.
///
/// {@category AST}
final class Interpolation implements SassNode {
  /// The contents of this interpolation.
  ///
  /// This contains [String]s and [Expression]s. It never contains two adjacent
  /// [String]s.
  final List<Object /* String | Expression */ > contents;

  /// The source spans for each [Expression] in [contents].
  ///
  /// Unlike [Expression.span], which just covers the expresssion itself, this
  /// should go from `#{` through `}`.
  ///
  /// @nodoc
  @internal
  final List<FileSpan?> spans;

  final FileSpan span;

  /// Returns whether this contains no interpolated expressions.
  bool get isPlain => asPlain != null;

  /// If this contains no interpolated expressions, returns its text contents.
  ///
  /// Otherwise, returns `null`.
  String? get asPlain =>
      switch (contents) { [] => '', [String first] => first, _ => null };

  /// Returns the plain text before the interpolation, or the empty string.
  ///
  /// @nodoc
  @internal
  String get initialPlain =>
      switch (contents) { [String first, ...] => first, _ => '' };

  /// Returns the [FileSpan] covering the element of the interpolation at
  /// [index].
  ///
  /// Unlike `contents[index].span`, which only covers the text of the
  /// expression itself, this typically covers the entire `#{}` that surrounds
  /// the expression. However, this is not a strong guarantee—there are cases
  /// where interpolations are constructed when the source uses Sass expressions
  /// directly where this may return the same value as `contents[index].span`.
  ///
  /// For string elements, this is the span that covers the entire text of the
  /// string, including the quote for text at the beginning or end of quoted
  /// strings. Note that the quote is *never* included for expressions.
  FileSpan spanForElement(int index) => switch (contents[index]) {
        String() => span.file.span(
            (index == 0 ? span.start : spans[index - 1]!.end).offset,
            (index == spans.length ? span.end : spans[index + 1]!.start)
                .offset),
        _ => spans[index]!
      };

  Interpolation.plain(String text, this.span)
      : contents = List.unmodifiable([text]),
        spans = const [null];

  /// Creates a new [Interpolation] with the given [contents].
  ///
  /// The [spans] must include a [FileSpan] for each [Expression] in [contents].
  /// These spans should generally cover the entire `#{}` surrounding the
  /// expression.
  ///
  /// The single [span] must cover the entire interpolation.
  Interpolation(Iterable<Object /* String | Expression */ > contents,
      Iterable<FileSpan?> spans, this.span)
      : contents = List.unmodifiable(contents),
        spans = List.unmodifiable(spans) {
    if (spans.length != contents.length) {
      throw ArgumentError.value(
          this.spans, "spans", "Must be the same length as contents.");
    }

    for (var i = 0; i < this.contents.length; i++) {
      var isString = this.contents[i] is String;
      if (!isString && this.contents[i] is! Expression) {
        throw ArgumentError.value(this.contents, "contents",
            "May only contain Strings or Expressions.");
      } else if (isString) {
        if (i != 0 && this.contents[i - 1] is String) {
          throw ArgumentError.value(
              this.contents, "contents", "May not contain adjacent Strings.");
        } else if (i < spans.length && this.spans[i] != null) {
          throw ArgumentError.value(this.spans, "spans",
              "May not have a value for string elements (at index $i).");
        }
      } else if (i >= spans.length || this.spans[i] == null) {
        throw ArgumentError.value(this.spans, "spans",
            "Must not have a value for expression elements (at index $i).");
      }
    }
  }

  String toString() =>
      contents.map((value) => value is String ? value : "#{$value}").join();
}
