// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:collection/collection.dart';
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:pub_api_client/pub_api_client.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'utils.dart';

@Task('Verify that the package is in a good state to release.')
Future<void> doubleCheckBeforeRelease() async {
  var ref = environment("GITHUB_REF");
  if (ref != "refs/tags/${pkg.version}") {
    fail("GITHUB_REF $ref is different than pubspec version ${pkg.version}.");
  }

  if (const ListEquality<Object?>().equals(pkg.version.preRelease, ["dev"])) {
    fail("${pkg.version} is a dev release.");
  }

  var versionHeader =
      RegExp("^## ${RegExp.escape(pkg.version.toString())}\$", multiLine: true);
  if (!File("CHANGELOG.md").readAsStringSync().contains(versionHeader)) {
    fail("There's no CHANGELOG entry for ${pkg.version}.");
  }

  var client = PubClient();
  try {
    for (var dir in [
      ".",
      ...Directory("pkg").listSync().map((entry) => entry.path)
    ]) {
      var pubspec = Pubspec.parse(File("$dir/pubspec.yaml").readAsStringSync(),
          sourceUrl: p.toUri("$dir/pubspec.yaml"));

      var package = await client.packageInfo(pubspec.name);
      if (pubspec.version == package.latestPubspec.version) {
        fail("${pubspec.name} ${pubspec.version} has already been released!");
      }
    }
  } finally {
    client.close();
  }
}
