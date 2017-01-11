// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import 'utils.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(ScheduledProcess runSass(List arguments)) {
  useSandbox();

  test("--help prints the usage documentation", () {
    // Checking the entire output is brittle, so just do a sanity check to make
    // sure it's not totally busted.
    var sass = runSass(["--help"]);
    sass.stdout.expect("Compile Sass to CSS.");
    sass.stdout
        .expect(consumeThrough(contains("Print this usage information.")));
    sass.shouldExit(64);
  });

  test("compiles a Sass file to CSS", () {
    d.file("test.scss", "a {b: 1 + 2}").create();

    var sass = runSass(["test.scss", "test.css"]);
    sass.stdout.expect(inOrder([
      "a {",
      "  b: 3;",
      "}",
    ]));
    sass.shouldExit(0);
  });

  test("supports relative imports", () {
    d.file("test.scss", "@import 'dir/test'").create();

    d.dir("dir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

    var sass = runSass(["test.scss", "test.css"]);
    sass.stdout.expect(inOrder([
      "a {",
      "  b: 3;",
      "}",
    ]));
    sass.shouldExit(0);
  });

  test("gracefully reports syntax errors", () {
    d.file("test.scss", "a {b: }").create();

    var sass = runSass(["test.scss", "test.css"]);
    sass.stderr.expect(inOrder([
      "Error: Expected expression.",
      "a {b: }",
      "      ^",
      "  test.scss 1:7",
    ]));
    sass.shouldExit(65);
  });

  test("gracefully reports runtime errors", () {
    d.file("test.scss", "a {b: 1px + 1deg}").create();

    var sass = runSass(["test.scss", "test.css"]);
    sass.stderr.expect(inOrder([
      "Error: Incompatible units deg and px.",
      "a {b: 1px + 1deg}",
      "      ^^^^^^^^^^",
      "  test.scss 1:7  root stylesheet",
    ]));
    sass.shouldExit(65);
  });

  test("reports errors with colors with --color", () {
    d.file("test.scss", "a {b: }").create();

    var sass = runSass(["--color", "test.scss", "test.css"]);
    sass.stderr.expect(inOrder([
      "Error: Expected expression.",
      "a {b: \u001b[31m\u001b[0m}",
      "      \u001b[31m^\u001b[0m",
      "  test.scss 1:7",
    ]));
    sass.shouldExit(65);
  });

  test("prints full stack traces with --trace", () {
    d.file("test.scss", "a {b: }").create();

    var sass = runSass(["--trace", "test.scss", "test.css"]);
    sass.stderr.expect(consumeThrough(contains("\.dart")));
    sass.shouldExit(65);
  });

  test("fails to import package uri", () {
    d.file("test.scss", "@import 'package:no_existing/test';").create();

    var sass = runSass(["test.scss", "test.css"]);
    sass.shouldExit();
    sass.stderr.expect(inOrder([
      "Error: Can't resolve: \"package:no_existing/test\", packageResolver is not supported by node vm."
          " If you are using dart-vm please provide a `SyncPackageResolver` to the `render` function",
      "@import 'package:no_existing/test';",
      "        ^^^^^^^^^^^^^^^^^^^^^^^^^^",
      "  test.scss 1:9  root stylesheet"
    ]));
  });
}
