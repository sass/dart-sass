// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';

import 'package:sass/src/utils.dart';

import 'utils.dart';

@Task('Verify that the package is in a good state to release.')
void sanityCheckBeforeRelease() {
  var ref = environment("GITHUB_REF");
  if (ref != "refs/tags/${pkg.version}") {
    fail("GITHUB_REF $ref is different than pubspec version ${pkg.version}.");
  }

  if (listEquals(pkg.version.preRelease, ["dev"])) {
    fail("${pkg.version} is a dev release.");
  }

  var versionHeader =
      RegExp("^## ${RegExp.escape(pkg.version.toString())}\$", multiLine: true);
  if (!File("CHANGELOG.md").readAsStringSync().contains(versionHeader)) {
    fail("There's no CHANGELOG entry for ${pkg.version}.");
  }
}
