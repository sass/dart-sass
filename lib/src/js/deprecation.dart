// Copyright 2023 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:pub_semver/pub_semver.dart';

import '../deprecation.dart';
import '../logger/js_to_dart.dart';
import 'hybrid/version.dart';
import 'reflection.dart';

@anonymous
extension type JSDeprecation._(JSObject _) implements JSObject {
  external String get id;
  external String get status;
  external String? get description;
  external JSVersion? get deprecatedIn;
  external JSVersion? get obsoleteIn;

  /// A record mapping deprecation names to deprecation objects.
  static final JSRecord<JSDeprecation> all = {
    for (var deprecation in dart.Deprecation.values)
      // `calc-interp` was never actually used, so we don't want to expose it
      // in the JS API.
      if (deprecation != dart.Deprecation.calcInterp)
        deprecation.id: JSDeprecation(
          id: deprecation.id,
          status: (() => switch (deprecation) {
                dart.Deprecation(isFuture: true) => 'future',
                dart.Deprecation(deprecatedIn: null, obsoleteIn: null) =>
                  'user',
                dart.Deprecation(obsoleteIn: null) => 'active',
                _ => 'obsolete',
              })(),
          description: deprecation.description,
          deprecatedIn: deprecation.deprecatedIn,
          obsoleteIn: deprecation.deprecatedIn,
        ),
  }.toJSRecord;

  external factory JSDeprecation({
    required String id,
    required String status,
    String? description,
    JSVersion? deprecatedIn,
    JSVersion? obsoleteIn,
  });

  /// Parses an array of [deprecations] from JS into an list of Dart
  /// [Deprecation] objects.
  ///
  /// [deprecations] can contain deprecation IDs, JS Deprecation objects, and
  /// (if [supportVersions] is true) [Version]s.
  static Iterable<dart.Deprecation>? arrayFromJS(
    Logger logger,
    JSArray<JSAny>? deprecations, {
    bool supportVersions = false,
  }) {
    if (deprecations == null) return null;
    return () sync* {
      for (var item in deprecations.toDart) {
        if (supportVersions && item.instanceofClass(JSVersion.jsClass)) {
          yield* dart.Deprecation.forVersion((item as JSVersion).toDart);
        } else {
          var id = item.isA<JSString>()
              ? (item as JSString).toDart
              : (item as JSDeprecation).id;
          var deprecation = dart.Deprecation.fromId(id);
          if (deprecation == null) {
            logger.warn('Invalid deprecation "$id".');
          } else {
            yield deprecation;
          }
        }
      }
    }();
  }
}
