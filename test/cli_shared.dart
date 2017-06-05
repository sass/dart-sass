// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  test("--help prints the usage documentation", () async {
    // Checking the entire output is brittle, so just do a sanity check to make
    // sure it's not totally busted.
    var sass = await runSass(["--help"]);
    expect(sass.stdout, emits("Compile Sass to CSS."));
    expect(
        sass.stdout, emitsThrough(contains("Print this usage information.")));
    await sass.shouldExit(64);
  });

  test("compiles a Sass file to CSS", () async {
    await d.file("test.scss", "a {b: 1 + 2}").create();

    var sass = await runSass(["test.scss", "test.css"]);
    expect(
        sass.stdout,
        emitsInOrder([
          "a {",
          "  b: 3;",
          "}",
        ]));
    await sass.shouldExit(0);
  });

  test("compiles Sass from stdin to CSS", () async {
    var sass = await runSass(["-"]);
    sass.stdin.writeln("a {b: 1 + 2}");
    sass.stdin.close();
    expect(sass.stdout, emitsInOrder([
      "a {",
      "  b: 3;",
      "}",
    ]));
    await sass.shouldExit(0);
  });

  test("supports relative imports", ()  async {
    await d.file("test.scss", "@import 'dir/test'").create();

    await d.dir("dir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

    var sass = await runSass(["test.scss", "test.css"]);
    expect(
        sass.stdout,
        emitsInOrder([
          "a {",
          "  b: 3;",
          "}",
        ]));
    await sass.shouldExit(0);
  });

  test("gracefully reports syntax errors", () async {
    await d.file("test.scss", "a {b: }").create();

    var sass = await runSass(["test.scss", "test.css"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Expected expression.",
          "a {b: }",
          "      ^",
          "  test.scss 1:7",
        ]));
    await sass.shouldExit(65);
  });

  test("gracefully reports runtime errors", () async {
    await d.file("test.scss", "a {b: 1px + 1deg}").create();

    var sass = await runSass(["test.scss", "test.css"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Incompatible units deg and px.",
          "a {b: 1px + 1deg}",
          "      ^^^^^^^^^^",
          "  test.scss 1:7  root stylesheet",
        ]));
    await sass.shouldExit(65);
  });

  test("reports errors with colors with --color", () async {
    await d.file("test.scss", "a {b: }").create();

    var sass = await runSass(["--color", "test.scss", "test.css"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Expected expression.",
          "a {b: \u001b[31m\u001b[0m}",
          "      \u001b[31m^\u001b[0m",
          "  test.scss 1:7",
        ]));
    await sass.shouldExit(65);
  });

  test("prints full stack traces with --trace", () async {
    await d.file("test.scss", "a {b: }").create();

    var sass = await runSass(["--trace", "test.scss", "test.css"]);
    expect(sass.stderr, emitsThrough(contains("\.dart")));
    await sass.shouldExit(65);
  });

  test("fails to import a package url", () async {
    await d.file("test.scss", "@import 'package:nope/test';").create();

    var sass = await runSass(["test.scss", "test.css"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: \"package:\" URLs aren't supported on this platform.",
          "@import 'package:nope/test';",
          "        ^^^^^^^^^^^^^^^^^^^",
          "  test.scss 1:9  root stylesheet"
        ]));
    await sass.shouldExit(65);
  });
}
