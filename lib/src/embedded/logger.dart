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
final class EmbeddedLogger implements DeprecationLogger {
  /// The [CompilationDispatcher] to which to send events.
  final CompilationDispatcher _dispatcher;

  /// Whether the formatted message should contain terminal colors.
  final bool _color;

  /// Whether the formatted message should use ASCII encoding.
  final bool _ascii;

  EmbeddedLogger(this._dispatcher, {bool color = false, bool ascii = false})
      : _color = color,
        _ascii = ascii;

  void debug(String message, SourceSpan span) {
    _dispatcher.sendLog(OutboundMessage_LogEvent()
      ..type = LogEventType.DEBUG
      ..message = message
      ..span = protofySpan(span)
      ..formatted = (span.start.sourceUrl.andThen(p.prettyUri) ?? '-') +
          ':${span.start.line + 1} ' +
          (_color ? '\u001b[1mDebug\u001b[0m' : 'DEBUG') +
          ': $message\n');
  }

  void warn(String message,
      {FileSpan? span,
      Trace? trace,
      bool deprecation = false,
      Deprecation? deprecationType}) {
    var formatted = withGlyphs(() {
      var buffer = StringBuffer();
      if (_color) {
        buffer.write('\u001b[33m\u001b[1m');
        if (deprecation) buffer.write('Deprecation ');
        buffer.write('Warning\u001b[0m');
      } else {
        if (deprecation) buffer.write('DEPRECATION ');
        buffer.write('WARNING');
      }
      if (span == null) {
        buffer.writeln(': $message');
      } else if (trace != null) {
        buffer.writeln(': $message\n\n${span.highlight(color: _color)}');
      } else {
        buffer.writeln(' on ${span.message("\n" + message, color: _color)}');
      }
      if (trace != null) {
        buffer.writeln(indent(trace.toString().trimRight(), 4));
      }
      return buffer.toString();
    }, ascii: _ascii);

    var event = OutboundMessage_LogEvent()
      ..type =
          deprecation ? LogEventType.DEPRECATION_WARNING : LogEventType.WARNING
      ..message = message
      ..formatted = formatted;
    if (span != null) event.span = protofySpan(span);
    if (trace != null) event.stackTrace = trace.toString();
    if (deprecationType != null) event.deprecationType = deprecationType.id;
    _dispatcher.sendLog(event);
  }
}
