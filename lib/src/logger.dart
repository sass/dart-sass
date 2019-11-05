// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/sass.dart' as sass;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'dispatcher.dart';
import 'embedded_sass.pb.dart' hide SourceSpan;
import 'utils.dart';

/// A Sass logger that sends log messages as `LogEvent`s.
class Logger implements sass.Logger {
  /// The [Dispatcher] to which to send events.
  final Dispatcher _dispatcher;

  /// The ID of the compilation to which this logger is passed.
  final int _compilationId;

  Logger(this._dispatcher, this._compilationId);

  void debug(String message, SourceSpan span) {
    _dispatcher.sendLog(OutboundMessage_LogEvent()
      ..compilationId = _compilationId
      ..type = OutboundMessage_LogEvent_Type.DEBUG
      ..message = message
      ..span = protofySpan(span));
  }

  void warn(String message,
      {FileSpan span, Trace trace, bool deprecation = false}) {
    var event = OutboundMessage_LogEvent()
      ..compilationId = _compilationId
      ..type = deprecation
          ? OutboundMessage_LogEvent_Type.DEPRECATION_WARNING
          : OutboundMessage_LogEvent_Type.WARNING
      ..message = message;
    if (span != null) event.span = protofySpan(span);
    if (trace != null) event.stackTrace = trace.toString();
    _dispatcher.sendLog(event);
  }
}
