// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../io.dart';
import '../logger.dart';
import '../utils.dart';

/// A logger that prints warnings to browser console.
class BrowserLogger implements Logger {
  /// Whether to use colors in messages.
  final bool color;

  const BrowserLogger({this.color = false});

  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    var result = '';
    if (color) {
      // Bold yellow.
      result += '\u001b[33m\u001b[1m';
      if (deprecation) result += 'Deprecation ';
      result += 'Warning\u001b[0m';
    } else {
      if (deprecation) result += 'DEPRECATION ';
      result += 'WARNING';
    }

    if (span == null) {
      result += ': $message\n';
    } else if (trace != null) {
      // If there's a span and a trace, the span's location information is
      // probably duplicated in the trace, so we just use it for highlighting.
      result += ': $message\n\n${span.highlight(color: color)}\n';
    } else {
      result += ' on ${span.message("\n" + message, color: color)}\n';
    }

    if (trace != null) result += '${indent(trace.toString().trimRight(), 4)}\n';
    console?.error(result);
  }

  void debug(String message, SourceSpan span) {
    var result = '';
    var url =
        span.start.sourceUrl == null ? '-' : p.prettyUri(span.start.sourceUrl);
    result += '$url:${span.start.line + 1} ';
    result += color ? '\u001b[1mDebug\u001b[0m' : 'DEBUG';
    result += ': $message\n';
    console?.warn(result);
  }
}
