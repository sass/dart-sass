// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:pub_semver/pub_semver.dart';

/// The JavaScript view of the [Version] type.
///
/// We modify the prototype of [Version] so that its instances are valid JS
/// objects with the expected types.
@anonymous
extension type JSVersion._(JSObject _) implements JSObject {
  static final JSClass<JSVersion> jsClass = () {
    var jsClass = JSClass(
        'sass.Version',
        (
          Object self,
          int major,
          int minor,
          int patch,
        ) {
          return Version(major, minor, patch).toJS;
        }.toJS);

    jsClass.defineStaticMethod(
        'parse',
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

  Version get toDart => this as Version;
}

extension VersionToJS on Version {
  JSVersion get toJS => this as JSVersion;
}
