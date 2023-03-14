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

  /// Whether repetitions of the same warning should be limited to no more than
  /// [_maxRepetitions].
  final bool limitRepetition;

  DeprecationHandlingLogger(this._inner,
      {required this.fatalDeprecations,
      required this.futureDeprecations,
      this.limitRepetition = true});

  void warn(String message,
      {FileSpan? span, Trace? trace, bool deprecation = false}) {
    _inner.warn(message, span: span, trace: trace, deprecation: deprecation);
  }

  /// Processes a deprecation warning.
  ///
  /// If [deprecation] is in [fatalDeprecations], this shows an error.
  ///
  /// If it's a future deprecation that hasn't been opted into or its a
  /// deprecation that's already been warned for [_maxReptitions] times and
  /// [limitRepetitions] is true, the warning is dropped.
  ///
  /// Otherwise, this is passed on to [warn].
  void warnForDeprecation(Deprecation deprecation, String message,
      {FileSpan? span, Trace? trace}) {
    if (fatalDeprecations.contains(deprecation)) {
      message += "\n\nThis is only an error because you've set the "
          '$deprecation deprecation to be fatal.\n'
          'Remove this setting if you need to keep using this feature.';
      if (span != null && trace != null) {
        throw SassRuntimeException(message, span, trace);
      }
      if (span == null) throw SassScriptException(message);
      throw SassException(message, span);
    }

    if (deprecation.isFuture && !futureDeprecations.contains(deprecation)) {
      return;
    }

    if (limitRepetition) {
      var count =
          _warningCounts[deprecation] = (_warningCounts[deprecation] ?? 0) + 1;
      if (count > _maxRepetitions) return;
    }

    warn(message, span: span, trace: trace, deprecation: true);
  }

  void debug(String message, SourceSpan span) => _inner.debug(message, span);

  /// Prints a warning indicating the number of deprecation warnings that were
  /// omitted due to repetition.
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
