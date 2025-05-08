// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import '../deprecation.dart';
import '../logger.dart';
import '../logger/js_to_dart.dart';
import 'deprecation.dart';
import 'logger.dart';

/// The base type for JS options that are shared between the legacy and modern
/// APIs.
extension type SharedOptions._(JSObject _) implements JSObject {
  @JS('quietDeps')
  external bool? get _quietDeps;

  /// Whether to suppress warnings from dependencies.
  bool get quietDeps => _quietDeps ?? false;

  @JS('verbose')
  external bool? get _verbose;

  /// Whether to emit all warnings, rather than stopping after a certain number
  /// of repetitions.
  bool get verbose => _verbose ?? false;

  @JS('charset')
  external bool? get _charset;

  /// Whether to emit a `@charset` declaration if the stylesheet contains
  /// non-ASCII characters.
  bool get charset => _charset ?? true;

  @JS('fatalDeprecations')
  external JSArray<JSAny /*JSDeprecation|String|Version*/ >?
      get _fatalDeprecations;

  @JS('futureDeprecations')
  external JSArray<JSAny /*JSDeprecation|String*/ >? get _futureDeprecations;

  @JS('silenceDeprecations')
  external JSArray<JSAny /*JSDeprecation|String*/ >? get _silenceDeprecations;

  @JS('logger')
  external JSLogger? get _logger;

  /// Returns the deprecations annotated as fatal by this options object.
  Iterable<Deprecation> fatalDeprecations(Logger logger) =>
      JSDeprecation.arrayFromJS(logger, _fatalDeprecations,
          supportVersions: true) ??
      const [];

  /// Returns the future deprecations enabled by this options object.
  Iterable<Deprecation> futureDeprecations(Logger logger) =>
      JSDeprecation.arrayFromJS(logger, _futureDeprecations) ?? const [];

  /// Returns the deprecations silenced by this options object.
  Iterable<Deprecation> silenceDeprecations(Logger logger) =>
      JSDeprecation.arrayFromJS(logger, _silenceDeprecations) ?? const [];

  // TODO - nweiz: Once we no longer have to support the legacy API, this can
  // construct the fallback and determine the ascii value based on the other
  // options, and so can be made a plain getter.

  /// Returns the Dart Sass [Logger] defined by these options.
  ///
  /// The [fallback] logger is used for logging methods that these options don't
  /// define. If [ascii] is passed, it overrides the default heuristics for
  /// whether only ascii characters should be used when rendering source spans.
  ///
  /// If this is null, the returned logger just calls [fallback] for everything.
  Logger logger(Logger fallback, {bool? ascii}) =>
      JSToDartLogger(_logger, fallback, ascii: ascii);
}
