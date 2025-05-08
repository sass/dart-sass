// Copyright 2023 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:pub_semver/pub_semver.dart';

import '../deprecation.dart';
import '../logger.dart';
import 'hybrid/version.dart';

extension type JSDeprecation._(JSObject _) implements JSObject {
  external String get id;
  external String get status;
  external String? get description;
  external UnsafeDartWrapper<Version>? get deprecatedIn;
  external UnsafeDartWrapper<Version>? get obsoleteIn;

  /// A record mapping deprecation names to deprecation objects.
  static final JSRecord<JSDeprecation> all = {
    for (var deprecation in Deprecation.values)
      // `calc-interp` was never actually used, so we don't want to expose it
      // in the JS API.
      if (deprecation != Deprecation.calcInterp)
        deprecation.id: JSDeprecation(
          id: deprecation.id,
          status: (() => switch (deprecation) {
                Deprecation(isFuture: true) => 'future',
                Deprecation(deprecatedIn: null, obsoleteIn: null) => 'user',
                Deprecation(obsoleteIn: null) => 'active',
                _ => 'obsolete',
              })(),
          description: deprecation.description,
          deprecatedIn: deprecation.deprecatedIn?.toJS,
          obsoleteIn: deprecation.deprecatedIn?.toJS,
        ),
  }.toJSRecord;

  external JSDeprecation({
    required String id,
    required String status,
    String? description,
    UnsafeDartWrapper<Version>? deprecatedIn,
    UnsafeDartWrapper<Version>? obsoleteIn,
  });

  /// Parses an array of [deprecations] from JS into an list of Dart
  /// [Deprecation] objects.
  ///
  /// [deprecations] can contain deprecation IDs, JS Deprecation objects, and
  /// (if [supportVersions] is true) [Version]s.
  static Iterable<Deprecation>? arrayFromJS(
    Logger logger,
    JSArray<JSAny>? deprecations, {
    bool supportVersions = false,
  }) {
    if (deprecations == null) return null;
    return () sync* {
      for (var item in deprecations.toDart) {
        if (item.asClassOrNull(VersionToJS.jsClass) case var version?
            when supportVersions) {
          yield* Deprecation.forVersion(version.toDart);
        } else {
          var id = item.isA<JSString>()
              ? (item as JSString).toDart
              : (item as JSDeprecation).id;
          var deprecation = Deprecation.fromId(id);
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
