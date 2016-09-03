// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

class SassException extends SourceSpanException {
  FileSpan get span => super.span as FileSpan;

  SassException(String message, FileSpan span) : super(message, span);
}

class SassRuntimeException extends SassException {
  final Trace trace;

  SassRuntimeException(String message, FileSpan span, this.trace)
      : super(message, span);

  String toString({color}) {
    var buffer = new StringBuffer(super.toString(color: color));
    for (var frame in trace.toString().split("\n")) {
      if (frame.isEmpty) continue;
      buffer.writeln();
      buffer.write("  $frame");
    }
    return buffer.toString();
  }
}

class SassFormatException extends SourceSpanFormatException
    implements SassException {
  FileSpan get span => super.span as FileSpan;

  String get source => span.file.getText(0);

  SassFormatException(String message, FileSpan span) : super(message, span);
}

class InternalException {
  final String message;

  InternalException(this.message);

  String toString() => "$message\n\nBUG: This should include a source span!";
}
