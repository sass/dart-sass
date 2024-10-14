// Copyright 2023 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:pub_semver/pub_semver.dart';

import '../deprecation.dart' as dart show Deprecation;
import '../logger/js_to_dart.dart';
import 'reflection.dart';

@JS()
@anonymous
class Deprecation {
  external String get id;
  external String get status;
  external String? get description;
  external Version? get deprecatedIn;
  external Version? get obsoleteIn;

  external factory Deprecation(
      {required String id,
      required String status,
      String? description,
      Version? deprecatedIn,
      Version? obsoleteIn});
}

final Map<String, Deprecation?> deprecations = {
  for (var deprecation in dart.Deprecation.values)
    // `calc-interp` was never actually used, so we don't want to expose it
    // in the JS API.
    if (deprecation != dart.Deprecation.calcInterp)
      deprecation.id: Deprecation(
          id: deprecation.id,
          status: (() => switch (deprecation) {
                dart.Deprecation(isFuture: true) => 'future',
                dart.Deprecation(deprecatedIn: null, obsoleteIn: null) =>
                  'user',
                dart.Deprecation(obsoleteIn: null) => 'active',
                _ => 'obsolete'
              })(),
          description: deprecation.description,
          deprecatedIn: deprecation.deprecatedIn,
          obsoleteIn: deprecation.deprecatedIn),
};

/// Parses a list of [deprecations] from JS into an list of Dart [Deprecation]
/// objects.
///
/// [deprecations] can contain deprecation IDs, JS Deprecation objects, and
/// (if [supportVersions] is true) [Version]s.
Iterable<dart.Deprecation>? parseDeprecations(
    JSToDartLogger logger, List<Object?>? deprecations,
    {bool supportVersions = false}) {
  if (deprecations == null) return null;
  return () sync* {
    for (var item in deprecations) {
      switch (item) {
        case String id:
          var deprecation = dart.Deprecation.fromId(id);
          if (deprecation == null) {
            logger.warn('Invalid deprecation "$id".');
          } else {
            yield deprecation;
          }
        case Deprecation(:var id):
          var deprecation = dart.Deprecation.fromId(id);
          if (deprecation == null) {
            logger.warn('Invalid deprecation "$id".');
          } else {
            yield deprecation;
          }
        case Version version when supportVersions:
          yield* dart.Deprecation.forVersion(version);
      }
    }
  }();
}

/// The JavaScript `Version` class.
final JSClass versionClass = () {
  var jsClass = createJSClass('sass.Version',
      (Object self, int major, int minor, int patch) {
    return Version(major, minor, patch);
  });

  jsClass.defineStaticMethod('parse', (String version) {
    var v = Version.parse(version);
    if (v.isPreRelease || v.build.isNotEmpty) {
      throw FormatException(
          'Build identifiers and prerelease versions not supported.');
    }
    return v;
  });

  getJSClass(Version(0, 0, 0)).injectSuperclass(jsClass);
  return jsClass;
}();
