// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:grinder/grinder.dart';
import 'package:pub_semver/pub_semver.dart';

import 'utils.dart';

@Task('Verify that the package is in a good state to release.')
sanityCheckBeforeRelease() {
  if (const ListEquality().equals(Version.parse(version).preRelease, ["dev"])) {
    fail("$version is a dev release.");
  }

  if (!File("CHANGELOG.md").readAsStringSync().contains(RegExp("^## ${RegExp.escape(version)}\$", multiLine: true))) {
    fail("There's no CHANGELOG entry for $version.");
  }
}
