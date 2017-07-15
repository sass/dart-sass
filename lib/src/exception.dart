// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'utils.dart';

/// An exception thrown by Sass.
class SassException extends SourceSpanException {
  /// The Sass stack trace at the point this exception was thrown.
  ///
  /// This includes [span].
  Trace get trace => new Trace([frameForSpan(span, "root stylesheet")]);

  FileSpan get span => super.span as FileSpan;

  SassException(String message, FileSpan span) : super(message, span);

  String toString({color}) {
    var buffer = new StringBuffer()
      ..writeln("Error: $message")
      ..write(span.highlight(color: color));

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

/// An exception thrown when Sass parsing has failed.
class SassFormatException extends SassException {
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
