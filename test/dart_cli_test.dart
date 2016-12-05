// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'cli_shared.dart';
import 'utils.dart';

void main() {
  sharedTests(_runSass);

  test("--version prints the Sass version", () {
    var sass = _runSass(["--version"]);
    sass.stdout.expect(matches(new RegExp(r"^\d+\.\d+\.\d+")));
    sass.shouldExit(0);
  });
}

ScheduledProcess _runSass(List arguments) => new ScheduledProcess.start(
    Platform.executable,
    <Object>[p.absolute("bin/sass.dart")]..addAll(arguments),
    workingDirectory: sandbox,
    description: "sass");
