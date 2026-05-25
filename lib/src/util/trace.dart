// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:stack_trace/stack_trace.dart';

/// Extensions for printing Trace
extension TraceExtensions on Trace {
  /// Returns a human-readable representation of this trace.
  ///
  /// This will not use `path.prettyUri()` when [prettyUri] is false.
  String printString({bool prettyUri = true}) {
    if (prettyUri) return toString();

    // Figure out the longest path so we know how much to pad.
    var longest =
        frames.map((frame) => frame._location.length).fold(0, math.max);

    // Print out the stack trace nicely formatted.
    return frames.map((frame) {
      if (frame is UnparsedFrame) return '$frame\n';
      return '${frame._location.padRight(longest)}  ${frame.member}\n';
    }).join();
  }
}

/// Extensions for printing Frame
extension FrameExtensions on Frame {
  /// Returns a human-friendly description of the library that this stack frame
  /// comes from.
  ///
  /// This will usually be the string form of [uri]. Absolute URIs will not be
  /// converted to relative URIs. Data URIs will be truncated.
  String get _library {
    if (uri.scheme == 'data') return 'data:...';
    return uri.toString();
  }

  /// A human-friendly description of the code location.
  String get _location {
    if (line == null) return _library;
    if (column == null) return '$_library $line';
    return '$_library $line:$column';
  }
}
