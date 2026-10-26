// Copyright 2023 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:node_interop/js.dart';

import '../deprecation.dart' as dart show Deprecation;
import '../logger/js_to_dart.dart';
import 'reflection.dart';
import 'utils.dart';

@JS()
@anonymous
class Deprecation {
  external String get id;
  external String get status;
  external String? get description;
  external Version? get deprecatedIn;
  external Version? get obsoleteIn;

  external factory({
    required String id,
    required String status,
    String? description,
    Version? deprecatedIn,
    Version? obsoleteIn,
  });
}

@JS()
@anonymous
class DeprecationSelectorDifference {
  external factory({required Object include, required Object exclude});

  /// Selector(s) indicating deprecations to include.
  external Object include;

  /// Specific deprecations to exclude.
  external Object exclude;
}

final Map<String, Deprecation?> deprecations = {
  for (var deprecation in dart.Deprecation.values)
    // `calc-interp` was never actually used, so we don't want to expose it
    // in the JS API.
    if (deprecation != .calcInterp)
      deprecation.id: Deprecation(
        id: deprecation.id,
        status: (() => switch (deprecation) {
          dart.Deprecation(isFuture: true) => 'future',
          dart.Deprecation(deprecatedIn: null, obsoleteIn: null) => 'user',
          dart.Deprecation(obsoleteIn: null) => 'active',
          _ => 'obsolete',
        })(),
        description: deprecation.description,
        deprecatedIn: deprecation.deprecatedIn,
        obsoleteIn: deprecation.obsoleteIn,
      ),
};

/// The JavaScript record that contains the JS deprecations.
final Object deprecationsObject = () {
  var result = jsify(deprecations) as Object;
  defineGetter(
    result,
    'dartSass2',
    value: DeprecationSelectorDifference(
      include: Version.parse('1.105.0'),
      exclude: [
        deprecations['color-module-compat'],
        deprecations['import'],
        deprecations['global-builtin'],
        deprecations['if-function'],
      ],
    ),
  );
  return result;
}();

/// Parses a list of [selectors] from JS into an list of Dart [Deprecation]
/// objects.
///
/// The [deprecations] can be any `DeprecationSelector`.
Iterable<dart.Deprecation> parseDeprecationSelector(
  JSToDartLogger logger,
  Object? selectors,
) {
  switch (selectors) {
    case null:
      return const [];
    case String id:
      var deprecation = dart.Deprecation.fromId(id);
      if (deprecation == null) {
        logger.warn('Invalid deprecation "$id".');
        return [];
      } else {
        return [deprecation];
      }
    case Deprecation(:var id):
      var deprecation = dart.Deprecation.fromId(id);
      if (deprecation == null) {
        logger.warn('Invalid deprecation "$id".');
        return [];
      } else {
        return [deprecation];
      }
    case Version version:
      return dart.Deprecation.forVersionInternal(version, logger);
    case List<Object> _:
      return [
        for (var selector in selectors)
          ...parseDeprecationSelector(logger, selector),
      ];
    default:
      var difference = selectors as DeprecationSelectorDifference;
      var include = {...parseDeprecationSelector(logger, difference.include)};
      for (var deprecation in parseDeprecations(logger, difference.exclude)) {
        if (!include.remove(deprecation)) {
          jsThrow(
            JsError(
              "The deprecation \"$deprecation\" was excluded from a "
              "DeprecationSelectorDifference that didn't include it.",
            ),
          );
        }
      }
      return include;
  }
}

/// Parses a list of [deprecations] from JS into an list of Dart [Deprecation]
/// objects.
///
/// The [deprecations] can be deprecation IDs, Deprecation objects, or lists
/// containing the same.
List<dart.Deprecation> parseDeprecations(
  JSToDartLogger logger,
  Object? deprecations,
) {
  if (deprecations == null) return [];
  if (deprecations is List<Object>) {
    return [
      for (var deprecation in deprecations)
        ?parseDeprecation(logger, deprecation),
    ];
  } else if (parseDeprecation(logger, deprecations) case var parsed?) {
    return [parsed];
  } else {
    return [];
  }
}

/// Parses a single [deprecation] from JS into a Dart [Deprecation] object, or
/// `null` if it's not a valid deprecation.
///
/// The [deprecation] can be a deprecation ID or a Deprecation object.
dart.Deprecation? parseDeprecation(JSToDartLogger logger, Object deprecation) {
  switch (deprecation) {
    case String id:
      var deprecation = dart.Deprecation.fromId(id);
      if (deprecation == null) {
        logger.warn('Invalid deprecation "$id".');
      } else {
        return deprecation;
      }
    case Deprecation(:var id):
      var deprecation = dart.Deprecation.fromId(id);
      if (deprecation == null) {
        logger.warn('Invalid deprecation "$id".');
      } else {
        return deprecation;
      }
    case _:
      logger.warn('Unknown deprecation value "${inspect(deprecation)}".');
  }
  return null;
}

/// The JavaScript `Version` class.
final JSClass versionClass = () {
  var jsClass = createJSClass('sass.Version', (
    Object self,
    int major,
    int minor,
    int patch,
  ) {
    return Version(major, minor, patch);
  });

  jsClass.defineStaticMethod('parse', (String version) {
    var v = Version.parse(version);
    if (v.isPreRelease || v.build.isNotEmpty) {
      throw FormatException(
        'Build identifiers and prerelease versions not supported.',
      );
    }
    return v;
  });

  getJSClass(Version(0, 0, 0)).injectSuperclass(jsClass);
  return jsClass;
}();
