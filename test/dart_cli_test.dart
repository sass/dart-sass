// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:path/path.dart' as p;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
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

  group("supports package imports", () {
    test("is found", () {
      d.file("test.scss", "a {b: 1 + 2}").create('lib');
      d.file("test.scss", "@import 'package:sass/test';").create();

      var sass = _runSass(["test.scss", "test.css"]);
      sass.stdout.expect(inOrder([
        "a {",
        "  b: 3;",
        "}",
      ]));
      sass.shouldExit(0);
    });

    test("is not found", () {
      d.file("test.scss", "@import 'package:no_existing/test';").create();

      var sass = _runSass(["test.scss", "test.css"]);
      sass.shouldExit();
      sass.stderr.expect(inOrder([
        "Error: Can't resolve: \"package:no_existing/test\"",
        "@import 'package:no_existing/test';",
        "        ^^^^^^^^^^^^^^^^^^^^^^^^^^",
        "  test.scss 1:9  root stylesheet"
      ]));
    });
  });
}

ScheduledProcess _runSass(List arguments) => new ScheduledProcess.start(
    Platform.executable,
    <Object>[p.absolute("bin/sass.dart")]..addAll(arguments),
    workingDirectory: sandbox,
    description: "sass");
