// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../logger.dart';
import '../node/logger.dart';

/// A wrapper around a [NodeLogger] that exposes it as a Dart [Logger].
class NodeToDartLogger implements Logger {
  /// The wrapped logger object.
  final NodeLogger? _node;

  /// The fallback logger to use if the [NodeLogger] doesn't define a method.
  final Logger _fallback;

  NodeToDartLogger(this._node, this._fallback);

  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    var warn = _node?.warn;
    if (warn == null) {
      _fallback.warn(message,
          span: span, trace: trace, deprecation: deprecation);
    } else {
      warn(
          message,
          WarnOptions(
              span: span, stack: trace.toString(), deprecation: deprecation));
    }
  }

  void debug(String message, SourceSpan span) {
    var debug = _node?.debug;
    if (debug == null) {
      _fallback.debug(message, span);
    } else {
      debug(message, DebugOptions(span: span));
    }
  }
}
