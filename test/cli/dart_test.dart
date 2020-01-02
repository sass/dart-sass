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

/// The path to the location of a precompiled Sass script will be if it exists.
final _scriptPath = p.absolute("build/sass${Platform.isWindows ? '.bat' : ''}");

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
  if (!File(_scriptPath).existsSync()) return;

  ensureUpToDate(_scriptPath, "pub run grinder pkg-standalone-dev");
}

Future<TestProcess> runSass(Iterable<String> arguments,
    {Map<String, String> environment}) {
  var executable = _scriptPath;
  var initialArguments = <String>[];
  if (!File(_scriptPath).existsSync()) {
    executable = Platform.executable;
    initialArguments = ["--enable-asserts", p.absolute("bin/sass.dart")];
  }

  return TestProcess.start(executable, [...initialArguments, ...arguments],
      workingDirectory: d.sandbox,
      environment: environment,
      description: "sass");
}
