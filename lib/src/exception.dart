// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as term_glyph;

import 'util/nullable.dart';
import 'utils.dart';
import 'value.dart';

/// An exception thrown by Sass.
///
/// {@category Compile}
@sealed
class SassException extends SourceSpanException {
  /// The Sass stack trace at the point this exception was thrown.
  ///
  /// This includes [span].
  Trace get trace => Trace([frameForSpan(span, "root stylesheet")]);

  FileSpan get span => super.span as FileSpan;

  SassException(String message, FileSpan span) : super(message, span);

  String toString({Object? color}) {
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
    var commentMessage = toString(color: false)
        // Replace comment-closing sequences in the error message with
        // visually-similar sequences that won't actually close the comment.
        .replaceAll("*/", "*∕")
        // If the original text contains CRLF newlines, replace them with LF
        // newlines to match the rest of the document.
        .replaceAll("\r\n", "\n");
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

/// A [SassException] that's also a [MultiSourceSpanException].
class MultiSpanSassException extends SassException
    implements MultiSourceSpanException {
  final String primaryLabel;
  final Map<FileSpan, String> secondarySpans;

  MultiSpanSassException(String message, FileSpan span, this.primaryLabel,
      Map<FileSpan, String> secondarySpans)
      : secondarySpans = Map.unmodifiable(secondarySpans),
        super(message, span);

  String toString({Object? color, String? secondaryColor}) {
    var useColor = false;
    String? primaryColor;
    if (color is String) {
      useColor = true;
      primaryColor = color;
    } else if (color == true) {
      useColor = true;
    }

    var buffer = StringBuffer("Error: $message\n");

    span
        .highlightMultiple(primaryLabel, secondarySpans,
            color: useColor,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor)
        .andThen(buffer.write);

    for (var frame in trace.toString().split("\n")) {
      if (frame.isEmpty) continue;
      buffer.writeln();
      buffer.write("  $frame");
    }
    return buffer.toString();
  }
}

/// An exception thrown by Sass while evaluating a stylesheet.
class SassRuntimeException extends SassException {
  final Trace trace;

  SassRuntimeException(String message, FileSpan span, this.trace)
      : super(message, span);
}

/// A [SassRuntimeException] that's also a [MultiSpanSassException].
class MultiSpanSassRuntimeException extends MultiSpanSassException
    implements SassRuntimeException {
  final Trace trace;

  MultiSpanSassRuntimeException(String message, FileSpan span,
      String primaryLabel, Map<FileSpan, String> secondarySpans, this.trace)
      : super(message, span, primaryLabel, secondarySpans);
}

/// An exception thrown when Sass parsing has failed.
///
/// {@category Parsing}
@sealed
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

  /// Creates a [SassScriptException] with the given [message].
  ///
  /// The [argumentName] is the name of the Sass function argument that
  /// triggered this exception. If it's not null, it's automatically included in
  /// [message].
  SassScriptException(String message, [String? argumentName])
    : message = argumentName == null ? message : "\$$argumentName: $message";

  String toString() => "$message\n\nBUG: This should include a source span!";
}

/// A [SassScriptException] that contains one or more additional spans to
/// display as points of reference.
class MultiSpanSassScriptException extends SassScriptException {
  /// See [MultiSourceSpanException.primaryLabel].
  final String primaryLabel;

  /// See [MultiSourceSpanException.secondarySpans].
  final Map<FileSpan, String> secondarySpans;

  MultiSpanSassScriptException(
      String message, this.primaryLabel, Map<FileSpan, String> secondarySpans)
      : secondarySpans = Map.unmodifiable(secondarySpans),
        super(message);
}
