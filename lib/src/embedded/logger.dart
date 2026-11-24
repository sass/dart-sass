// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../deprecation.dart';
import '../logger.dart';
import '../util/nullable.dart';
import '../utils.dart';
import 'compilation_dispatcher.dart';
import 'embedded_sass.pb.dart' hide SourceSpan;
import 'utils.dart';

/// A Sass logger that sends log messages as `LogEvent`s.
final class EmbeddedLogger(
  /// The [CompilationDispatcher] to which to send events.
  final CompilationDispatcher _dispatcher, {

  /// Whether the formatted message should contain terminal colors.
  final bool _color = false,

  /// Whether the formatted message should use ASCII encoding.
  final bool _ascii = false,
}) extends LoggerWithDeprecationType {
  @override
  void debug(String message, SourceSpan span) {
    _dispatcher.sendLog(
      OutboundMessage_LogEvent()
        ..type = LogEventType.DEBUG
        ..message = message
        ..span = protofySpan(span)
        ..formatted =
            '${span.start.sourceUrl.andThen(p.prettyUri) ?? '-'}:'
            '${span.start.line + 1} '
            '${_color ? '\u001b[1mDebug\u001b[0m' : 'DEBUG'}: $message\n',
    );
  }

  @override
  void internalWarn(
    String message, {
    FileSpan? span,
    Trace? trace,
    Deprecation? deprecation,
  }) {
    var formattedSpanOffset = 0;
    var formattedStackTraceOffset = 0;
    var formatted = withGlyphs(() {
      var buffer = StringBuffer();
      var showDeprecation = deprecation != null && deprecation != .userAuthored;
      if (_color) {
        buffer.write('\u001b[33m\u001b[1m');
        if (deprecation != null) buffer.write('Deprecation ');
        buffer.write('Warning\u001b[0m');
        if (showDeprecation) buffer.write(' [\u001b[34m$deprecation\u001b[0m]');
      } else {
        if (deprecation != null) buffer.write('DEPRECATION ');
        buffer.write('WARNING');
        if (showDeprecation) buffer.write(' [$deprecation]');
      }
      buffer.writeln(': $message');
      formattedSpanOffset = buffer.length;
      if (span != null) buffer.writeln(span.highlight(color: _color));
      formattedStackTraceOffset = buffer.length;
      if (trace != null) {
        buffer.writeln(indent(trace.toString().trimRight(), 2));
      } else if (span != null) {
        trace = Trace([
          Frame(
            span.sourceUrl ?? Uri.parse('-'),
            span.start.line,
            span.start.column,
            'root stylesheet',
          ),
        ]);
        buffer.writeln(indent(trace.toString().trimRight(), 2));
      }

      return buffer.toString();
    }, ascii: _ascii);

    var event = OutboundMessage_LogEvent()
      ..type = deprecation != null
          ? LogEventType.DEPRECATION_WARNING
          : LogEventType.WARNING
      ..message = message
      ..formatted = formatted
      ..formattedSpanOffset = formattedSpanOffset
      ..formattedStackTraceOffset = formattedStackTraceOffset;
    if (span != null) event.span = protofySpan(span);
    if (trace != null) event.stackTrace.addAll(protofyStackTrace(trace!));
    if (deprecation != null) event.deprecationType = deprecation.id;
    _dispatcher.sendLog(event);
  }
}
