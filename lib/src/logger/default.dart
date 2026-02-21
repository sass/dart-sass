// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../deprecation.dart';
import '../io.dart';
import '../logger.dart';
import 'stderr.dart';

/// The logger "wrapped" by [DefaultLogger].
///
/// This must be global because it's assigned based on non-const function
/// results.
StderrLogger? _default;

/// A logger that wraps [StderrLogger] and chooses whether to activate colors
/// based on whether the current system supports it.
final class DefaultLogger extends LoggerWithDeprecationType {
  const DefaultLogger();

  /// Ensures [_defaultStderr] is initialized and returns it.
  StderrLogger get _inner {
    return _default ??= StderrLogger(color: supportsAnsiEscapes);
  }

  void internalWarn(
    String message, {
    FileSpan? span,
    Trace? trace,
    Deprecation? deprecation,
  }) =>
      _inner.internalWarn(message,
          span: span, trace: trace, deprecation: deprecation);

  void debug(String message, SourceSpan span) => _inner.debug(message, span);
}
