// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.
import 'dart:math' as math;

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';

/// A silent Sass-style comment.
class SilentComment implements Statement {
  /// The text of this comment, including comment characters.
  final String text;

  /// The text of this comment that are marked as a documentation comment
  /// (leading triple slashes).
  ///
  /// Provided with slashes and common leading whitespace removed.
  String get docComment => _cleanup(text);

  final FileSpan span;

  SilentComment(this.text, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitSilentComment(this);

  // Matches '///' followed by some amount of whitespace.
  final _leadingWhitespace = RegExp('^(\/\/\/[\t ]*)[^\t ]?');

  // Returns a string formed from lines of this comment that begin with '///'
  // trimmed to remove the slashes and common leading whitespace.
  String _cleanup(String text) {
    // Only lines with leading '///'.
    var lines = text.split('\n').where((line) => line.startsWith('///'));
    if (lines.isEmpty) return null;

    // Count the common whitespace after '///' on all lines.
    int min;
    for (var line in lines) {
      var match = _leadingWhitespace.firstMatch(line);
      var matchLength = match.group(1).length;

      // Line is empty after '///'.
      if (matchLength == 3) continue;

      min = (min == null || matchLength < min) ? matchLength : min;
    }

    // Trim the '///' and common whitespace from all lines
    var buffer = StringBuffer();
    for (var line in lines) {
      var trimLength = math.min(line.length, min);
      buffer.writeln(line.substring(trimLength));
    }

    return buffer.toString().trimRight();
  }

  String toString() => text;
}
