// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../logger.dart';

/// The maximum number of repetitions of the same warning [TerseLogger] will
/// emit before hiding the rest.
const _maxRepetitions = 5;

/// A logger that wraps an inner logger to omit repeated deprecation warnings.
///
/// A warning is considered "repeated" if the first paragraph is the same as
/// another warning that's already been emitted.
class TerseLogger implements Logger {
  /// A map from the first paragraph of a warning to the number of times this
  /// logger has emitted a warning with that line.
  final _warningCounts = <String, int>{};

  final Logger _inner;

  TerseLogger(this._inner);

  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    if (deprecation) {
      var firstParagraph = message.split("\n\n").first;
      var count = _warningCounts[firstParagraph] =
          (_warningCounts[firstParagraph] ?? 0) + 1;
      if (count > _maxRepetitions) return;
    }

    _inner.warn(message, span: span, trace: trace, deprecation: deprecation);
  }

  void debug(String message, SourceSpan span) => _inner.debug(message, span);

  /// Prints a warning indicating the number of deprecation warnings that were
  /// omitted.
  ///
  /// The [node] flag indicates whether this is running in Node.js mode, in
  /// which case it doesn't mention "verbose mode" because the Node API doesn't
  /// support that.
  void summarize({required bool node}) {
    var total = _warningCounts.values
        .where((count) => count > _maxRepetitions)
        .map((count) => count - _maxRepetitions)
        .sum;
    if (total > 0) {
      _inner.warn("$total repetitive deprecation warnings omitted." +
          (node ? "" : "\nRun in verbose mode to see all warnings."));
    }
  }
}
