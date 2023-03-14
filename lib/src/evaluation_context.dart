// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:source_span/source_span.dart';

import 'deprecation.dart';

/// An interface that exposes information about the current Sass evaluation.
///
/// This allows us to expose zone-scoped information without having to create a
/// new zone variable for each piece of information.
abstract class EvaluationContext {
  /// The current evaluation context.
  ///
  /// Throws [StateError] if there isn't a Sass stylesheet currently being
  /// evaluated.
  static EvaluationContext get current {
    var context = Zone.current[#_evaluationContext];
    if (context is EvaluationContext) return context;
    throw StateError("No Sass stylesheet is currently being evaluated.");
  }

  /// Returns the span for the currently executing callable.
  ///
  /// For normal exception reporting, this should be avoided in favor of
  /// throwing [SassScriptException]s. It should only be used when calling APIs
  /// that require spans.
  ///
  /// Throws a [StateError] if there isn't a callable being invoked.
  FileSpan get currentCallableSpan;

  /// Prints a warning message associated with the current `@import` or function
  /// call.
  ///
  /// If [deprecation] is non-null, the warning is emitted as a deprecation
  /// warning of that type.
  void warn(String message, [Deprecation? deprecation]);
}

/// Prints a warning message associated with the current `@import` or function
/// call.
///
/// If [deprecation] is `true`, the warning is emitted as a deprecation warning.
///
/// This may only be called within a custom function or importer callback.
/// {@category Compile}
void warn(String message, {bool deprecation = false}) =>
    EvaluationContext.current
        .warn(message, deprecation ? Deprecation.userAuthored : null);

/// Prints a deprecation warning with [message] of type [deprecation].
void warnForDeprecation(String message, Deprecation deprecation) {
  EvaluationContext.current.warn(message, deprecation);
}

/// Runs [callback] with [context] as [EvaluationContext.current].
///
/// This is zone-based, so if [callback] is asynchronous [warn] is set for the
/// duration of that callback.
T withEvaluationContext<T>(EvaluationContext context, T callback()) =>
    runZoned(callback, zoneValues: {#_evaluationContext: context});
