// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'io.dart';
import 'util/path.dart';
import 'utils.dart';

/// An interface for loggers that print messages produced by Sass stylesheets.
///
/// This may be implemented by user code.
abstract class Logger {
  /// A logger that silently ignores all messages.
  static final Logger quiet = new _QuietLogger();

  /// Creates a logger that prints warnings to standard error, with terminal
  /// colors if [color] is `true` (default `false`).
  const factory Logger.stderr({bool color}) = _StderrLogger;

  /// Emits a warning with the given [message].
  ///
  /// If [span] is passed, it's the location in the Sass source that generated
  /// the warning. If [trace] is passed, it's the Sass stack trace when the
  /// warning was issued. If [deprecation] is `true`, it indicates that this is
  /// a deprecation warning. Implementations should surface all this information
  /// to the end user.
  void warn(String message,
      {FileSpan span, Trace trace, bool deprecation: false});

  /// Emits a debugging message associated with the given [span].
  void debug(String message, SourceSpan span);
}

/// A logger that emits no messages.
class _QuietLogger implements Logger {
  void warn(String message,
      {FileSpan span, Trace trace, bool deprecation: false}) {}
  void debug(String message, SourceSpan span) {}
}

/// A logger that prints warnings to standard error.
class _StderrLogger implements Logger {
  /// Whether to use terminal colors in messages.
  final bool color;

  const _StderrLogger({this.color: false});

  void warn(String message,
      {FileSpan span, Trace trace, bool deprecation: false}) {
    if (color) {
      // Bold yellow.
      stderr.write('\u001b[33m\u001b[1m');
      if (deprecation) stderr.write('Deprecation ');
      stderr.write('Warning\u001b[0m');
    } else {
      if (deprecation) stderr.write('DEPRECATION ');
      stderr.write('WARNING');
    }

    if (span == null) {
      stderr.writeln(': $message');
    } else if (trace != null) {
      // If there's a span and a trace, the span's location information is
      // probably duplicated in the trace, so we just use it for highlighting.
      stderr.writeln(': $message\n\n${span.highlight(color: color)}');
    } else {
      stderr.writeln(' on ${span.message("\n" + message, color: color)}');
    }

    if (trace != null) stderr.writeln(indent(trace.toString().trimRight(), 4));
    stderr.writeln();
  }

  void debug(String message, SourceSpan span) {
    stderr
        .write('${p.prettyUri(span.start.sourceUrl)}:${span.start.line + 1} ');
    stderr.write(color ? '\u001b[1mDebug\u001b[0m' : 'DEBUG');
    stderr.writeln(': $message');
  }
}
