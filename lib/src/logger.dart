// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'deprecation.g.dart';
import 'logger/deprecation_processing.dart';
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
  const factory Logger.stderr({bool color}) = StderrLogger;

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

/// A base class for loggers that support the [Deprecation] object, rather than
/// just a boolean flag for whether a warnings is a deprecation warning or not.
///
/// In Dart Sass 2.0.0, we will eliminate this interface and change
/// [Logger.warn]'s signature to match that of [internalWarn]. This is used
/// in the meantime to provide access to the [Deprecation] object to internal
/// loggers.
///
/// Implementers should override the protected [internalWarn] method instead of
/// [warn].
@internal
abstract class LoggerWithDeprecationType implements Logger {
  /// This forwards all calls to [internalWarn].
  ///
  /// For non-user deprecation warnings, the [warnForDeprecation] extension
  /// method should be called instead.
  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    internalWarn(message,
        span: span,
        trace: trace,
        deprecation: deprecation ? Deprecation.userAuthored : null);
  }

  /// Equivalent to [Logger.warn], but for internal loggers that support
  /// the [Deprecation] object.
  ///
  /// Subclasses of this logger should override this method instead of [warn].
  @protected
  void internalWarn(String message,
      {FileSpan? span, Trace? trace, Deprecation? deprecation});
}

/// An extension to add a `warnForDeprecation` method to loggers without
/// making a breaking API change.
@internal
extension WarnForDeprecation on Logger {
  /// Emits a deprecation warning for [deprecation] with the given [message].
  void warnForDeprecation(Deprecation deprecation, String message,
      {FileSpan? span, Trace? trace}) {
    if (deprecation.isFuture && this is! DeprecationProcessingLogger) return;
    if (this case LoggerWithDeprecationType self) {
      self.internalWarn(message,
          span: span, trace: trace, deprecation: deprecation);
    } else {
      warn(message, span: span, trace: trace, deprecation: true);
    }
  }
}

/// A logger that emits no messages.
final class _QuietLogger implements Logger {
  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {}
  void debug(String message, SourceSpan span) {}
}
