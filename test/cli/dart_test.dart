// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import 'package:cli_pkg/testing.dart' as pkg;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'shared.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);

  sharedTests(runSass);

  test("--version prints the Sass version", () async {
    var sass = await runSass(["--version"]);
    expect(sass.stdout, emits(matches(RegExp(r"^\d+\.\d+\.\d+"))));
    await sass.shouldExit(0);
  });
}

/// Ensures that the snapshot of the Dart executable used by [runSass] is
/// up-to-date, if one has been generated.
void ensureSnapshotUpToDate() => pkg.ensureExecutableUpToDate("sass");

Future<TestProcess> runSass(Iterable<String> arguments,
        {Map<String, String>? environment}) =>
    pkg.start("sass", arguments,
        environment: environment, workingDirectory: d.sandbox, encoding: utf8);
