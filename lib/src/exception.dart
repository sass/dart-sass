// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as term_glyph;

import 'utils.dart';
import 'value.dart';

/// An exception thrown by Sass.
class SassException extends SourceSpanException {
  /// The Sass stack trace at the point this exception was thrown.
  ///
  /// This includes [span].
  Trace get trace => Trace([frameForSpan(span, "root stylesheet")]);

  FileSpan get span => super.span as FileSpan;

  SassException(String message, FileSpan span) : super(message, span);

  String toString({Object color}) {
    var buffer = StringBuffer()
      ..writeln("Error: $message")
      ..write(span.highlight(color: color));

    for (var frame in trace.toString().split("\n")) {
      if (frame.isEmpty) continue;
      buffer.writeln();
      buffer.write("  $frame");
    }
    return buffer.toString();
  }

  /// Returns the contents of a CSS stylesheet that will display this error
  /// message above the current page.
  String toCssString() {
    // Don't render the error message in Unicode for the inline comment, since
    // we can't be sure the user's default encoding is UTF-8.
    var wasAscii = term_glyph.ascii;
    term_glyph.ascii = true;
    // Replace comment-closing sequences in the error message with
    // visually-similar sequences that won't actually close the comment.
    var commentMessage = toString(color: false).replaceAll("*/", "*∕");
    term_glyph.ascii = wasAscii;

    // For the string comment, render all non-ASCII characters as escape
    // sequences so that they'll show up even if the HTTP headers are set
    // incorrectly.
    var stringMessage = StringBuffer();
    for (var rune in SassString(toString(color: false)).toString().runes) {
      if (rune > 0xFF) {
        stringMessage
          ..writeCharCode($backslash)
          ..write(rune.toRadixString(16))
          ..writeCharCode($space);
      } else {
        stringMessage.writeCharCode(rune);
      }
    }

    return """
/* ${commentMessage.split("\n").join("\n * ")} */

body::before {
  font-family: "Source Code Pro", "SF Mono", Monaco, Inconsolata, "Fira Mono",
      "Droid Sans Mono", monospace, monospace;
  white-space: pre;
  display: block;
  padding: 1em;
  margin-bottom: 1em;
  border-bottom: 2px solid black;
  content: $stringMessage;
}""";
  }
}

/// An exception thrown by Sass while evaluating a stylesheet.
class SassRuntimeException extends SassException {
  final Trace trace;

  SassRuntimeException(String message, FileSpan span, this.trace)
      : super(message, span);
}

/// An exception thrown when Sass parsing has failed.
class SassFormatException extends SassException
    implements SourceSpanFormatException {
  String get source => span.file.getText(0);

  int get offset => span.start.offset;

  SassFormatException(String message, FileSpan span) : super(message, span);
}

/// An exception thrown by SassScript.
///
/// This doesn't extends [SassException] because it doesn't (yet) have a
/// [FileSpan] associated with it. It's caught by Sass's internals and converted
/// to a [SassRuntimeException] with a source span and a stack trace.
class SassScriptException {
  /// The error message.
  final String message;

  SassScriptException(this.message);

  String toString() => "$message\n\nBUG: This should include a source span!";
}
