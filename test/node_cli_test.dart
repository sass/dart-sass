// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@Tags(const ['node'])
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test_process/test_process.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test/test.dart';

import 'cli_shared.dart';

void main() {
  setUpAll(() async {
    var grinder = await TestProcess
        .start(Platform.executable, ["tool/grind.dart", "npm_package"]);
    await grinder.shouldExit(0);
  });

  sharedTests(_runSass);

  test("--version prints the Sass and dart2js versions", () async {
    var sass = await _runSass(["--version"]);
    expect(
        sass.stdout,
        emits(matches(new RegExp(
            r"^\d+\.\d+\.\d+.* compiled with dart2js \d+\.\d+\.\d+"))));
    await sass.shouldExit(0);
  });
}

Future<TestProcess> _runSass(Iterable<String> arguments) => TestProcess.start(
    "node", [p.absolute("build/npm/sass.js")]..addAll(arguments),
    workingDirectory: d.sandbox, description: "sass");
