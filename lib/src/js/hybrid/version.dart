// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:pub_semver/pub_semver.dart';

import '../extension/class.dart';

extension VersionToJS on Version {
  /// The JavaScript view of the [Version] type.
  ///
  /// We modify the prototype of [Version] so that its instances are valid JS
  /// objects with the expected types.
  static final JSClass<UnsafeDartWrapper<Version>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<Version>>((
      UnsafeDartWrapper<Version> _,
      int major,
      int minor,
      int patch,
    ) {
      return Version(major, minor, patch).toJS;
    }.toJS);

    jsClass.defineStaticMethod(
        'parse'.toJS,
        (String version) {
          var v = Version.parse(version);
          if (v.isPreRelease || v.build.isNotEmpty) {
            throw FormatException(
              'Build identifiers and prerelease versions not supported.',
            );
          }
          return v.toJS;
        }.toJS);

    Version(0, 0, 0).toJS.constructor.injectSuperclass(jsClass);
    return jsClass;
  }();

  UnsafeDartWrapper<Version> get toJS => toUnsafeWrapper;
}
