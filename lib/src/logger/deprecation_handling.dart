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
final class DeprecationHandlingLogger implements DeprecationLogger {
  /// A map of how many times each deprecation has been emitted by this logger.
  final _warningCounts = <Deprecation, int>{};

  final Logger _inner;

  /// Deprecation warnings of these types will be ignored.
  final Set<Deprecation> silenceDeprecations;

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
      {required this.silenceDeprecations,
      required this.fatalDeprecations,
      required this.futureDeprecations,
      this.limitRepetition = true}) {
    for (var deprecation in fatalDeprecations) {
      if (deprecation.isFuture && !futureDeprecations.contains(deprecation)) {
        warn('Future $deprecation deprecation must be enabled before it can be '
            'made fatal.');
      } else if (deprecation.obsoleteIn != null) {
        warn('$deprecation deprecation is obsolete, so does not need to be '
            'made fatal.');
      } else if (silenceDeprecations.contains(deprecation)) {
        warn('Ignoring setting to silence $deprecation deprecation, since it '
            'has also been made fatal.');
      }
    }
    for (var deprecation in silenceDeprecations) {
      if (deprecation == Deprecation.userAuthored) {
        warn('User-authored deprecations should not be silenced.');
      } else if (deprecation.obsoleteIn != null) {
        warn('$deprecation deprecation is obsolete. If you were previously '
            'silencing it, your code may now behave in unexpected ways.');
      } else if (deprecation.isFuture) {
        if (futureDeprecations.contains(deprecation)) {
          warn('Conflicting options for future $deprecation deprecation cancel '
              'each other out.');
        } else {
          warn('Future $deprecation deprecation is not yet active, so '
              'silencing it is unnecessary.');
        }
      }
    }
    for (var deprecation in futureDeprecations) {
      if (!deprecation.isFuture) {
        warn('$deprecation is not a future deprecation, so it does not need to '
            'be explicitly enabled.');
      }
    }
  }

  void warn(String message,
      {FileSpan? span,
      Trace? trace,
      bool deprecation = false,
      Deprecation? deprecationType}) {
    if (deprecation && deprecationType != null) {
      _handleDeprecation(deprecationType, message, span: span, trace: trace);
    } else {
      _inner.warn(message, span: span, trace: trace);
    }
  }

  /// Processes a deprecation warning.
  ///
  /// If [deprecation] is in [fatalDeprecations], this shows an error.
  ///
  /// If it's a future deprecation that hasn't been opted into or it's a
  /// deprecation that's already been warned for [_maxReptitions] times and
  /// [limitRepetitions] is true, the warning is dropped.
  ///
  /// Otherwise, this is passed on to [warn].
  void _handleDeprecation(Deprecation deprecation, String message,
      {FileSpan? span, Trace? trace}) {
    if (deprecation.isFuture && !futureDeprecations.contains(deprecation)) {
      return;
    }

    if (fatalDeprecations.contains(deprecation)) {
      message += "\n\nThis is only an error because you've set the "
          '$deprecation deprecation to be fatal.\n'
          'Remove this setting if you need to keep using this feature.';
      throw switch ((span, trace)) {
        (var span?, var trace?) => SassRuntimeException(message, span, trace),
        (var span?, null) => SassException(message, span),
        _ => SassScriptException(message)
      };
    }
    if (silenceDeprecations.contains(deprecation)) return;

    if (limitRepetition) {
      var count =
          _warningCounts[deprecation] = (_warningCounts[deprecation] ?? 0) + 1;
      if (count > _maxRepetitions) return;
    }

    if (_inner case DeprecationLogger inner) {
      inner.warn(message,
          span: span,
          trace: trace,
          deprecation: true,
          deprecationType: deprecation);
    } else {
      _inner.warn(message, span: span, trace: trace, deprecation: true);
    }
  }

  void debug(String message, SourceSpan span) => _inner.debug(message, span);

  /// Prints a warning indicating the number of deprecation warnings that were
  /// omitted due to repetition.
  ///
  /// The [js] flag indicates whether this is running in JS mode, in which case
  /// it doesn't mention "verbose mode" because the JS API doesn't support that.
  void summarize({required bool js}) {
    var total = _warningCounts.values
        .where((count) => count > _maxRepetitions)
        .map((count) => count - _maxRepetitions)
        .sum;
    if (total > 0) {
      _inner.warn("$total repetitive deprecation warnings omitted." +
          (js ? "" : "\nRun in verbose mode to see all warnings."));
    }
  }
}
