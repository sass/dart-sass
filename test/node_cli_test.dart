// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@Tags(const ['node'])
import 'dart:io';

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:path/path.dart' as p;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'cli_shared.dart';
import 'utils.dart';

void main() {
  setUpAll(() {
    var grinder = new ScheduledProcess.start(
        Platform.executable, ["tool/grind.dart", "npm_package"]);
    grinder.shouldExit(0);
  });

  sharedTests(_runSass);

  test("--version prints the Sass and dart2js versions", () {
    var sass = _runSass(["--version"]);
    sass.stdout.expect(matches(
        new RegExp(r"^\d+\.\d+\.\d+.* compiled with dart2js \d+\.\d+\.\d+")));
    sass.shouldExit(0);
  });

  test("fails to import package uri", () {
    d.file("test.scss", "@import 'package:sass/test';").create();

    var sass = _runSass(["test.scss", "test.css"]);
    sass.shouldExit();
    sass.stderr.expect(inOrder([
      "Error: Can't resolve: \"package:sass/test\", packageResolver is not supported by node vm."
          " If you are using dart-vm please use `renderAsync` function or provide a `packageResolver`",
      "@import 'package:sass/test';",
      "        ^^^^^^^^^^^^^^^^^^^",
      "  test.scss 1:9  root stylesheet"
    ]));
  });
}

ScheduledProcess _runSass(List arguments) => new ScheduledProcess.start(
    "node", <Object>[p.absolute("build/npm/sass.js")]..addAll(arguments),
    workingDirectory: sandbox, description: "sass");
