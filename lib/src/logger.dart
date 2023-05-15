// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'deprecation.dart';
import 'io.dart';
import 'logger/deprecation_handling.dart';
import 'logger/browser.dart';
import 'logger/stderr.dart';

/// An interface for loggers that print messages produced by Sass stylesheets.
///
/// This may be implemented by user code.
///
/// {@category Compile}
abstract class Logger {
  /// A logger that silently ignores all messages.
  static final Logger quiet = _QuietLogger();

  /// Creates a logger that prints warnings to standard error, with terminal
  /// colors if [color] is `true` (default `false`).
  factory Logger.stderr({bool color = false}) {
    if (isBrowser) {
      return BrowserLogger(color: color);
    }
    return StderrLogger(color: color);
  }

  /// Emits a warning with the given [message].
  ///
  /// If [span] is passed, it's the location in the Sass source that generated
  /// the warning. If [trace] is passed, it's the Sass stack trace when the
  /// warning was issued. If [deprecation] is `true`, it indicates that this is
  /// a deprecation warning. Implementations should surface all this information
  /// to the end user.
  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false});

  /// Emits a debugging message associated with the given [span].
  void debug(String message, SourceSpan span);
}

/// An extension to add a `warnForDeprecation` method to loggers without
/// making a breaking API change.
@internal
extension WarnForDeprecation on Logger {
  /// Emits a deprecation warning for [deprecation] with the given [message].
  void warnForDeprecation(Deprecation deprecation, String message,
      {FileSpan? span, Trace? trace}) {
    var self = this;
    if (self is DeprecationHandlingLogger) {
      self.warnForDeprecation(deprecation, message, span: span, trace: trace);
    } else if (!deprecation.isFuture) {
      warn(message, span: span, trace: trace, deprecation: true);
    }
  }
}

/// A logger that emits no messages.
class _QuietLogger implements Logger {
  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {}
  void debug(String message, SourceSpan span) {}
}
