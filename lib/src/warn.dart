// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

/// Prints a warning message associated with the current `@import` or function
/// call.
///
/// If [deprecation] is `true`, the warning is emitted as a deprecation warning.
///
/// This may only be called within a custom function or importer callback.
void warn(String message, {bool deprecation = false}) {
  var warnDefinition = Zone.current[#_warn];

  if (warnDefinition == null) {
    throw ArgumentError(
        "warn() may only be called within a custom function or importer "
        "callback.");
  }

  warnDefinition(message, deprecation);
}

/// Runs [callback] with [warn] as the definition for the top-level `warn()`
/// function and [error] as a similar function that errors.
///
/// This is zone-based, so if [callback] is asynchronous, [warn] and [error] are
/// set for the duration of that callback.
T withWarnCallback<T>(void warn(String message, bool deprecation),
    Never error(String message), T callback()) {
  return runZoned(() {
    return callback();
  }, zoneValues: {#_warn: warn, #_error: error});
}

/// Runs [callback] with [fatalDeprecations].
///
/// This is zone-based, so if [callback] is asynchronous, the given deprecations
/// are fatal for the duration of that callback.
T withFatalDeprecations<T>(Set<Deprecation> fatalDeprecations, T callback()) {
  return runZoned(() {
    return callback();
  }, zoneValues: {#_fatalDeprecations: fatalDeprecations});
}

/// Represents a piece of deprecated functionality in the language.
class Deprecation {
  /// The identifier for this deprecation, which can be passed on the command
  /// line to the `--fatal-deprecation` option.
  ///
  /// This must be unique among all deprecations.
  final String id;

  /// A short description of the functionality being deprecated.
  ///
  /// Any instance of `{argument}` or `{function}` in this string will be
  /// replaced with the corresponding arguments to [message] or [warnOrError].
  final String description;

  /// The version the deprecated functionality will be removed in, e.g. `2.0.0`
  /// or null if this is not yet known.
  final String? removedIn;

  /// When true, [description] should instead describe the future behavior that
  /// will be used as of [removedIn].
  final bool describesFutureBehavior;

  /// A URL with more information about this deprecation.
  final String? url;

  /// Whether or not an automatic migrator exists for this deprecation.
  final bool hasMigrator;

  /// The recommended change that should be used when no `recommendation` is
  /// passed to [message] or [warnOrError].
  final String? defaultRecommendation;

  Deprecation._(this.id, this.description,
      {this.removedIn,
      this.describesFutureBehavior = false,
      this.url,
      this.hasMigrator = false,
      this.defaultRecommendation});

  /// The deprecation for using `color.alpha()` in a Microsoft filter.
  static final alphaFilter = Deprecation._(
      'alpha-filter', 'Using color.alpha() for a Microsoft filter');

  /// The deprecation for passing a string to `call` instead of using
  /// `get-function`.
  static final callString = Deprecation._(
      'call-string', 'Passing a string to call()',
      removedIn: '2.0.0');

  /// The deprecation for passing a number to a function in the color module.
  static final colorNumber = Deprecation._(
      'color-number', 'Passing a number ({argument}) to color.{function}()');

  /// The deprecation for `@elseif`.
  static final elseif =
      Deprecation._('elseif', '@elseif', defaultRecommendation: '@else if');

  /// The deprecation for declaring new variables with `!global`.
  static final globalDeclaration = Deprecation._('global-declaration',
      "!global assignments won't be able to declare new variables",
      removedIn: '2.0.0', describesFutureBehavior: true);

  /// The deprecation for passing numbers without % to saturation or lightness
  /// parameters.
  static final hslPercent = Deprecation._(
      'hsl-percent', 'Passing a number without unit % ({argument})',
      url: 'https://sass-lang.com/d/color-units');

  /// The deprecation for passing units other than `deg` to a hue parameter.
  static final hueUnits = Deprecation._(
      'hue-units', 'Passing a unit other than deg ({argument})',
      url: 'https://sass-lang.com/d/color-units');

  /// The deprecation for parsing `@-moz-document`.
  static final mozDocument = Deprecation._('moz-document', '@-moz-document',
      removedIn: '2.0.0', url: 'https://bit.ly/MozDocument');

  /// The deprecation for treating `/` as division.
  static final slashAsDivision = Deprecation._(
      'slash-as-division', 'Using / for division',
      removedIn: '2.0.0',
      url: 'https://sass-lang.com/d/slash-div',
      hasMigrator: true);

  /// The set of all current deprecations.
  static final all = Set.unmodifiable({
    alphaFilter,
    callString,
    colorNumber,
    elseif,
    globalDeclaration,
    hslPercent,
    hueUnits,
    mozDocument,
    slashAsDivision
  });

  /// A map between deprecation IDs and deprecation they refer to.
  static final byId = Map<String, Deprecation>.unmodifiable(
      {for (var item in all) item.id: item});

  /// Constructs a deprecation warning for this deprecation based on its
  /// properties and the arguments passed here.
  ///
  /// [argument] is the deprecated argument passed to a built-in function.
  /// [function] is the name of a built-in function with deprecated behavior.
  /// [context] is additional context for the deprecation that will be included
  ///   after the default description.
  /// [recommendation] is the recommended change to the code in question to
  ///   avoid the deprecated behavior. This overrides [defaultRecommendation] if
  ///   it exists.
  /// [currentBehavior] is a recommended change that preserves the current
  ///   behavior, while [newBehavior] is a recommended change that migrates to
  ///   the future behavior once the deprecation is complete.
  String message(
      {Object? argument,
      String? function,
      String? context,
      String? recommendation,
      String? currentBehavior,
      String? newBehavior}) {
    var buffer = StringBuffer();
    if (describesFutureBehavior) {
      buffer.write(removedIn == null
          ? 'In a future version of Sass, '
          : 'As of Dart Sass $removedIn, ');
    }
    var description = this.description;
    if (argument != null) {
      description = description.replaceAll('{argument}', '$argument');
    }
    if (function != null) {
      description = description.replaceAll('{function}', function);
    }
    buffer.write(description);
    if (!describesFutureBehavior) {
      buffer.write(' is deprecated');
      if (removedIn != null) {
        buffer.write(' and will be removed in Dart Sass $removedIn');
      }
    }
    buffer.writeln('.');

    if (context != null) buffer..writeln()..writeln(context);

    recommendation ??= defaultRecommendation;
    if (recommendation != null ||
        currentBehavior != null ||
        newBehavior != null) {
      buffer.writeln();
    }
    if (recommendation != null) {
      buffer.writeln('Recommendation: $recommendation');
    }
    if (currentBehavior != null) {
      buffer.writeln('To preserve current behavior: $currentBehavior');
    }
    if (newBehavior != null) {
      buffer.writeln('To migrate to new behavior: $newBehavior');
    }
    if (url != null) {
      buffer
        ..writeln()
        ..write(hasMigrator ? 'More info and automated migrator:' : 'See')
        ..writeln(' $url');
    }
    return buffer.toString();
  }

  /// Returns true if this deprecation is treated as fatal.
  ///
  /// This will be false unless inside a [withFatalDeprecations] callback that
  /// included this deprecation.
  bool get isFatal {
    var fatalDeprecations = Zone.current[#_fatalDeprecations];
    if (fatalDeprecations is! Set<Deprecation>) return false;
    return fatalDeprecations.contains(this);
  }

  /// Emits a warning or errors based on [isFatal].
  ///
  /// This will only work when inside a [withWarnCallback] callback.
  ///
  /// The arguments here are the same as those of [message].
  void warnOrError(
      {Object? argument,
      String? function,
      String? context,
      String? recommendation,
      String? currentBehavior,
      String? newBehavior}) {
    var msg = message(
        argument: argument,
        function: function,
        context: context,
        recommendation: recommendation,
        currentBehavior: currentBehavior,
        newBehavior: newBehavior);
    if (isFatal) {
      Zone.current[#_error](msg);
    } else {
      warn(msg, deprecation: true);
    }
  }
}
