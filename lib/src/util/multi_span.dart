// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

/// A FileSpan wrapper that with secondary spans attached, so that
/// [MultiSpan.message] can forward to [SourceSpanExtension.messageMultiple].
///
/// This is used to transparently support multi-span messages in situations that
/// need to be backwards-comaptible with single spans, such as logger
/// invocations. To match the `source_span` package, separate APIs should
/// generally be preferred over this class wherever backwards compatibility
/// isn't a concern.
class MultiSpan implements FileSpan {
  /// The span to primarily highlight.
  final FileSpan _primary;

  /// The label for [primary].
  final String primaryLabel;

  /// The [secondarySpans] map for [SourceSpanExtension.messageMultiple].
  final Map<SourceSpan, String> secondarySpans;

  MultiSpan(FileSpan primary, String primaryLabel,
      Map<SourceSpan, String> secondarySpans)
      : this._(primary, primaryLabel, Map.unmodifiable(secondarySpans));

  MultiSpan._(this._primary, this.primaryLabel, this.secondarySpans);

  FileLocation get start => _primary.start;
  FileLocation get end => _primary.end;
  String get text => _primary.text;
  String get context => _primary.context;
  SourceFile get file => _primary.file;
  int get length => _primary.length;
  Uri? get sourceUrl => _primary.sourceUrl;
  int compareTo(SourceSpan other) => _primary.compareTo(other);
  String toString() => _primary.toString();
  MultiSpan expand(FileSpan other) => _withPrimary(_primary.expand(other));
  SourceSpan union(SourceSpan other) => _primary.union(other);
  MultiSpan subspan(int start, [int? end]) =>
      _withPrimary(_primary.subspan(start, end));

  String highlight({dynamic color}) =>
      _primary.highlightMultiple(primaryLabel, secondarySpans,
          color: color == true || color is String,
          primaryColor: color is String ? color : null);

  String message(String message, {dynamic color}) =>
      _primary.messageMultiple(message, primaryLabel, secondarySpans,
          color: color == true || color is String,
          primaryColor: color is String ? color : null);

  String highlightMultiple(
          String newLabel, Map<SourceSpan, String> additionalSecondarySpans,
          {bool color = false, String? primaryColor, String? secondaryColor}) =>
      _primary.highlightMultiple(
          newLabel, {...secondarySpans, ...additionalSecondarySpans},
          color: color,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor);

  String messageMultiple(String message, String newLabel,
          Map<SourceSpan, String> additionalSecondarySpans,
          {bool color = false, String? primaryColor, String? secondaryColor}) =>
      _primary.messageMultiple(
          message, newLabel, {...secondarySpans, ...additionalSecondarySpans},
          color: color,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor);

  /// Returns a copy of `this` with [newPrimary] as its primary span.
  MultiSpan _withPrimary(FileSpan newPrimary) =>
      MultiSpan._(newPrimary, primaryLabel, secondarySpans);
}
