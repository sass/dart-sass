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
  var travisTag = environment("TRAVIS_TAG");
  if (travisTag != version) {
    fail("TRAVIS_TAG $travisTag is different than pubspec version $version.");
  }

  if (const ListEquality().equals(Version.parse(version).preRelease, ["dev"])) {
    fail("$version is a dev release.");
  }

  var versionHeader =
      RegExp("^## ${RegExp.escape(version)}\$", multiLine: true);
  if (!File("CHANGELOG.md").readAsStringSync().contains(versionHeader)) {
    fail("There's no CHANGELOG entry for $version.");
  }
}
