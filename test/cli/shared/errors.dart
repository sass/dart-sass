// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  test("from invalid arguments", () async {
    var sass = await runSass(["--asdf"]);
    expect(
        sass.stdout, emitsThrough(contains("Print this usage information.")));
    await sass.shouldExit(64);
  });

  test("from too many positional arguments", () async {
    var sass = await runSass(["abc", "def", "ghi"]);
    expect(
        sass.stdout, emitsThrough(contains("Print this usage information.")));
    await sass.shouldExit(64);
  });

  test("from too many positional arguments with --stdin", () async {
    var sass = await runSass(["--stdin", "abc", "def"]);
    expect(
        sass.stdout, emitsThrough(contains("Print this usage information.")));
    await sass.shouldExit(64);
  });

  test("from a file that doesn't exist", () async {
    var sass = await runSass(["asdf"]);
    expect(sass.stderr, emits(startsWith("Error reading asdf:")));
    expect(sass.stderr, emitsDone);
    await sass.shouldExit(66);
  });

  test("from invalid syntax", () async {
    await d.file("test.scss", "a {b: }").create();

    var sass = await runSass(["test.scss"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Expected expression.",
          "a {b: }",
          "      ^",
          "  test.scss 1:7  root stylesheet",
        ]));
    await sass.shouldExit(65);
  });

  test("from the runtime", () async {
    await d.file("test.scss", "a {b: 1px + 1deg}").create();

    var sass = await runSass(["test.scss"]);
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

  test("with colors with --color", () async {
    await d.file("test.scss", "a {b: }").create();

    var sass = await runSass(["--color", "test.scss"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Expected expression.",
          "a {b: \u001b[31m\u001b[0m}",
          "      \u001b[31m^\u001b[0m",
          "  test.scss 1:7  root stylesheet",
        ]));
    await sass.shouldExit(65);
  });

  test("with full stack traces with --trace", () async {
    await d.file("test.scss", "a {b: }").create();

    var sass = await runSass(["--trace", "test.scss"]);
    expect(sass.stderr, emitsThrough(contains("\.dart")));
    await sass.shouldExit(65);
  });

  test("for package urls", () async {
    await d.file("test.scss", "@import 'package:nope/test';").create();

    var sass = await runSass(["test.scss"]);
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
