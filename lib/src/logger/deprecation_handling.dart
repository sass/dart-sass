// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../deprecation.dart';
import '../exception.dart';
import '../logger.dart';

/// The maximum number of repetitions of the same warning
/// [DeprecationHandlingLogger] will emit before hiding the rest.
const _maxRepetitions = 5;

/// A logger that wraps an inner logger to have special handling for
/// deprecation warnings.
class DeprecationHandlingLogger implements Logger {
  /// A map of how many times each deprecation has been emitted by this logger.
  final _warningCounts = <Deprecation, int>{};

  final Logger _inner;

  /// Deprecation warnings of one of these types will cause an error to be
  /// thrown.
  ///
  /// Future deprecations in this list will still cause an error even if they
  /// are not also in [futureDeprecations].
  final Set<Deprecation> fatalDeprecations;

  /// Future deprecations that the user has explicitly opted into.
  final Set<Deprecation> futureDeprecations;

  DeprecationHandlingLogger(this._inner,
      {required this.fatalDeprecations, required this.futureDeprecations});

  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    _inner.warn(message, span: span, trace: trace, deprecation: deprecation);
  }

  void handleDeprecationWarning(
      Deprecation deprecation, String message, FileSpan? span, Trace? trace) {
    // Throw an exception if a deprecation is fatal.
    if (fatalDeprecations.contains(deprecation)) {
      message += '\nThis is only an error because of '
          '--fatal-deprecation=$deprecation.\n'
          'Remove this flag if you still need to use this feature.';
      if (span != null && trace != null) {
        throw SassRuntimeException(message, span, trace);
      }
      if (span == null) throw SassScriptException(message);
      throw SassException(message, span);
    }

    // Only emit a future deprecation warning if the user has opted-in.
    if (deprecation.deprecatedIn == null &&
        !futureDeprecations.contains(deprecation)) {
      return;
    }

    var count =
        _warningCounts[deprecation] = (_warningCounts[deprecation] ?? 0) + 1;
    if (count > _maxRepetitions) return;

    warn(message, span: span, trace: trace, deprecation: true);
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
