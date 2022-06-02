// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../utils.dart';
import 'character.dart';

extension SpanExtensions on FileSpan {
  /// Returns this span with all whitespace trimmed from both sides.
  FileSpan trim() => trimLeft().trimRight();

  /// Returns this span with all leading whitespace trimmed.
  FileSpan trimLeft() {
    var start = 0;
    while (isWhitespace(text.codeUnitAt(start))) {
      start++;
    }
    return subspan(start);
  }

  /// Returns this span with all trailing whitespace trimmed.
  FileSpan trimRight() {
    var end = text.length - 1;
    while (isWhitespace(text.codeUnitAt(end))) {
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

  /// Whether [this] FileSpan contains the [target] FileSpan.
  ///
  /// Validates the FileSpans to be in the same file and for the [target] to be
  /// within [this] FileSpan non-inclusive range (start, end).
  bool contains(FileSpan target) =>
      file.url == target.file.url &&
      start.offset < target.start.offset &&
      end.offset > target.end.offset;
}

/// Consumes an identifier from [scanner].
void _scanIdentifier(StringScanner scanner) {
  while (!scanner.isDone) {
    var char = scanner.peekChar()!;
    if (char == $backslash) {
      consumeEscapedCharacter(scanner);
    } else if (isName(char)) {
      scanner.readChar();
    } else {
      break;
    }
  }
}
