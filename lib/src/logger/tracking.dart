// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../logger.dart';

/// An logger that wraps another logger and keeps track of when it is used.
class TrackingLogger implements Logger {
  final Logger _logger;
  bool _emittedWarning = false;
  bool _emittedDebug = false;

  /// True if [warn] has been called on this logger; false otherwise.
  bool get emittedWarning => _emittedWarning;

  /// True if [debug] has been called on this logger; false otherwise.
  bool get emittedDebug => _emittedDebug;

  TrackingLogger(this._logger);

  void warn(String message,
      {FileSpan span, Trace trace, bool deprecation: false}) {
    _emittedWarning = true;
    _logger.warn(message, span: span, trace: trace, deprecation: deprecation);
  }

  void debug(String message, SourceSpan span) {
    _emittedDebug = true;
    _logger.debug(message, span);
  }
}
