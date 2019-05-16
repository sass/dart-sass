// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import '../io.dart';
import 'shared.dart';

/// Paths where snapshots of the Sass binary might exist, in order of
/// preference.
final _snapshotPaths = [
  p.absolute("build/sass.dart.app.snapshot"),
  p.absolute("build/sass.dart.snapshot")
];

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
void ensureSnapshotUpToDate() {
  for (var path in _snapshotPaths) {
    if (File(path).existsSync()) {
      ensureUpToDate(path, "pub run grinder app-snapshot");
      return;
    }
  }
}

Future<TestProcess> runSass(Iterable<String> arguments,
    {Map<String, String> environment}) {
  var executable = _snapshotPaths.firstWhere((path) => File(path).existsSync(),
      orElse: () => p.absolute("bin/sass.dart"));

  return TestProcess.start(
      Platform.executable,
      [
        "--enable-asserts",
        // Work around dart-lang/sdk#33622.
        if (Platform.isWindows)
          "--packages=${p.absolute('.packages')}",

        executable,
        ...arguments
      ],
      workingDirectory: d.sandbox,
      environment: environment,
      description: "sass");
}
