// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../utils.dart';
import 'character.dart';

/// A span that points nowhere.
///
/// This is used for fake AST nodes that will never be presented to the user, as
/// well as for embedded compilation failures that have no associated spans.
final bogusSpan = SourceFile.decoded([]).span(0);

extension SpanExtensions on FileSpan {
  /// Returns this span with all whitespace trimmed from both sides.
  FileSpan trim() => trimLeft().trimRight();

  /// Returns this span with all leading whitespace trimmed.
  FileSpan trimLeft() {
    var start = 0;
    while (text.codeUnitAt(start).isWhitespace) {
      start++;
    }
    return subspan(start);
  }

  /// Returns this span with all trailing whitespace trimmed.
  FileSpan trimRight() {
    var end = text.length - 1;
    while (text.codeUnitAt(end).isWhitespace) {
      end--;
    }
    return subspan(0, end + 1);
  }

  /// Returns the span of the identifier at the start of this span.
  ///
  /// If [includeLeading] is greater than 0, that many additional characters
  /// will be included from the start of this span before looking for an
  /// identifier.
  FileSpan initialIdentifier({int includeLeading = 0}) {
    var scanner = StringScanner(text);
    for (var i = 0; i < includeLeading; i++) {
      scanner.readChar();
    }
    _scanIdentifier(scanner);
    return subspan(0, scanner.position);
  }

  /// Returns a subspan excluding the identifier at the start of this span.
  FileSpan withoutInitialIdentifier() {
    var scanner = StringScanner(text);
    _scanIdentifier(scanner);
    return subspan(scanner.position);
  }

  /// Returns a subspan excluding a namespace and `.` at the start of this span.
  FileSpan withoutNamespace() => withoutInitialIdentifier().subspan(1);

  /// Returns the span of the quoted text at the start of this span.
  ///
  /// This span must start with `"` or `'`.
  FileSpan initialQuoted() {
    var scanner = StringScanner(text);
    var quote = scanner.readChar();
    while (true) {
      var next = scanner.readChar();
      if (next == quote) break;
      if (next == $backslash) scanner.readChar();
    }
    return subspan(0, scanner.position);
  }

  /// Returns a subspan excluding an initial at-rule and any whitespace after
  /// it.
  FileSpan withoutInitialAtRule() {
    var scanner = StringScanner(text);
    scanner.expectChar($at);
    _scanIdentifier(scanner);
    return subspan(scanner.position).trimLeft();
  }

  /// Returns a span covering the text after this span and before [other].
  ///
  /// Throws an [ArgumentError] if [other.start] isn't on or after `this.end` in
  /// the same file.
  FileSpan between(FileSpan other) {
    if (sourceUrl != other.sourceUrl) {
      throw ArgumentError("$this and $other are in different files.");
    } else if (end.offset > other.start.offset) {
      throw ArgumentError("$this isn't before $other.");
    }

    return file.span(end.offset, other.start.offset);
  }

  /// Returns a span covering the text from the beginning of this span to the
  /// beginning of [inner].
  ///
  /// Throws an [ArgumentError] if [inner] isn't fully within this span.
  FileSpan before(FileSpan inner) {
    if (sourceUrl != inner.sourceUrl) {
      throw ArgumentError("$this and $inner are in different files.");
    } else if (inner.start.offset < start.offset ||
        inner.end.offset > end.offset) {
      throw ArgumentError("$inner isn't inside $this.");
    }

    return file.span(start.offset, inner.start.offset);
  }

  /// Returns a span covering the text from the end of [inner] to the end of
  /// this span.
  ///
  /// Throws an [ArgumentError] if [inner] isn't fully within this span.
  FileSpan after(FileSpan inner) {
    if (sourceUrl != inner.sourceUrl) {
      throw ArgumentError("$this and $inner are in different files.");
    } else if (inner.start.offset < start.offset ||
        inner.end.offset > end.offset) {
      throw ArgumentError("$inner isn't inside $this.");
    }

    return file.span(inner.end.offset, end.offset);
  }

  /// Whether this [FileSpan] contains the [target] FileSpan.
  ///
  /// Validates the FileSpans to be in the same file and for the [target] to be
  /// within this [FileSpan]'s inclusive range `[start,end]`.
  bool contains(FileSpan target) =>
      file.url == target.file.url &&
      start.offset <= target.start.offset &&
      end.offset >= target.end.offset;
}

/// Consumes an identifier from [scanner].
void _scanIdentifier(StringScanner scanner) {
  loop:
  while (!scanner.isDone) {
    switch (scanner.peekChar()) {
      case $backslash:
        consumeEscapedCharacter(scanner);
      case int(isName: true):
        scanner.readChar();
      case _:
        break loop;
    }
  }
}
