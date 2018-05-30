// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'logger/stderr.dart';

/// An interface for loggers that print messages produced by Sass stylesheets.
///
/// This may be implemented by user code.
abstract class Logger {
  /// A logger that silently ignores all messages.
  static final Logger quiet = new _QuietLogger();

  /// Creates a logger that prints warnings to standard error, with terminal
  /// colors if [color] is `true` (default `false`).
  const factory Logger.stderr({bool color}) = StderrLogger;

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
