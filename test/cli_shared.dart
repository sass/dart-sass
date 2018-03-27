// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  /// Runs the executable on [arguments] plus an output file, then verifies that
  /// the contents of the output file match [expected].
  Future expectCompiles(List<String> arguments, expected) async {
    var sass = await runSass(arguments.toList()..add("out.css"));
    await sass.shouldExit(0);
    await d.file("out.css", expected).validate();
  }

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

    var sass = await runSass(["test.scss"]);
    expect(
        sass.stdout,
        emitsInOrder([
          "a {",
          "  b: 3;",
          "}",
        ]));
    await sass.shouldExit(0);
  });

  test("writes a CSS file to disk", () async {
    await d.file("test.scss", "a {b: 1 + 2}").create();

    var sass = await runSass(["test.scss", "out.css"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
    await d.file("out.css", equalsIgnoringWhitespace("a { b: 3; }")).validate();
  });

  test("compiles from stdin with the magic path -", () async {
    var sass = await runSass(["-"]);
    sass.stdin.writeln("a {b: 1 + 2}");
    sass.stdin.close();
    expect(
        sass.stdout,
        emitsInOrder([
          "a {",
          "  b: 3;",
          "}",
        ]));
    await sass.shouldExit(0);
  });

  group("can import files", () {
    test("relative to the entrypoint", () async {
      await d.file("test.scss", "@import 'dir/test'").create();

      await d.dir("dir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

      await expectCompiles(
          ["test.scss"], equalsIgnoringWhitespace("a { b: 3; }"));
    });

    test("from the load path", () async {
      await d.file("test.scss", "@import 'test2'").create();

      await d.dir("dir", [d.file("test2.scss", "a {b: c}")]).create();

      await expectCompiles(["--load-path", "dir", "test.scss"],
          equalsIgnoringWhitespace("a { b: c; }"));
    });

    test("relative in preference to from the load path", () async {
      await d.file("test.scss", "@import 'test2'").create();
      await d.file("test2.scss", "x {y: z}").create();

      await d.dir("dir", [d.file("test2.scss", "a {b: c}")]).create();

      await expectCompiles(["--load-path", "dir", "test.scss"],
          equalsIgnoringWhitespace("x { y: z; }"));
    });

    test("in load path order", () async {
      await d.file("test.scss", "@import 'test2'").create();

      await d.dir("dir1", [d.file("test2.scss", "a {b: c}")]).create();
      await d.dir("dir2", [d.file("test2.scss", "x {y: z}")]).create();

      await expectCompiles(
          ["--load-path", "dir2", "--load-path", "dir1", "test.scss"],
          equalsIgnoringWhitespace("x { y: z; }"));
    });
  });

  group("with --stdin", () {
    test("compiles from stdin", () async {
      var sass = await runSass(["--stdin"]);
      sass.stdin.writeln("a {b: 1 + 2}");
      sass.stdin.close();
      expect(
          sass.stdout,
          emitsInOrder([
            "a {",
            "  b: 3;",
            "}",
          ]));
      await sass.shouldExit(0);
    });

    test("writes a CSS file to disk", () async {
      var sass = await runSass(["--stdin", "out.css"]);
      sass.stdin.writeln("a {b: 1 + 2}");
      sass.stdin.close();
      expect(sass.stdout, emitsDone);

      await sass.shouldExit(0);
      await d
          .file("out.css", equalsIgnoringWhitespace("a { b: 3; }"))
          .validate();
    });

    test("uses the indented syntax with --indented", () async {
      var sass = await runSass(["--stdin", "--indented"]);
      sass.stdin.writeln("a\n  b: 1 + 2");
      sass.stdin.close();
      expect(
          sass.stdout,
          emitsInOrder([
            "a {",
            "  b: 3;",
            "}",
          ]));
      await sass.shouldExit(0);
    });
  });

  test("gracefully reports errors from stdin", () async {
    var sass = await runSass(["-"]);
    sass.stdin.writeln("a {b: 1 + }");
    sass.stdin.close();
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Expected expression.",
          "a {b: 1 + }",
          "          ^",
          "  - 1:11  root stylesheet",
        ]));
    await sass.shouldExit(65);
  });

  test("supports relative imports", () async {
    await d.file("test.scss", "@import 'dir/test'").create();

    await d.dir("dir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

    var sass = await runSass(["test.scss"]);
    expect(
        sass.stdout,
        emitsInOrder([
          "a {",
          "  b: 3;",
          "}",
        ]));
    await sass.shouldExit(0);
  });

  group("with --quiet", () {
    test("doesn't emit @warn", () async {
      await d.file("test.scss", "@warn heck").create();

      var sass = await runSass(["--quiet", "test.scss"]);
      expect(sass.stderr, emitsDone);
      await sass.shouldExit(0);
    });

    test("doesn't emit @debug", () async {
      await d.file("test.scss", "@debug heck").create();

      var sass = await runSass(["--quiet", "test.scss"]);
      expect(sass.stderr, emitsDone);
      await sass.shouldExit(0);
    });

    test("doesn't emit parser warnings", () async {
      await d.file("test.scss", "a {b: c && d}").create();

      var sass = await runSass(["--quiet", "test.scss"]);
      expect(sass.stderr, emitsDone);
      await sass.shouldExit(0);
    });

    test("doesn't emit runner warnings", () async {
      await d.file("test.scss", "#{blue} {x: y}").create();

      var sass = await runSass(["--quiet", "test.scss"]);
      expect(sass.stderr, emitsDone);
      await sass.shouldExit(0);
    });
  });

  group("reports errors", () {
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
  });
}
