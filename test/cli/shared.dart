// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(
    Future<TestProcess> runSass(Iterable<String> arguments,
        {Map<String, String> environment})) {
  /// Runs the executable on [arguments] plus an output file, then verifies that
  /// the contents of the output file match [expected].
  Future<void> expectCompiles(List<String> arguments, Object expected,
      {Map<String, String> environment}) async {
    var sass = await runSass([...arguments, "out.css", "--no-source-map"],
        environment: environment);
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

  // Regression test for #437.
  test("compiles a Sass file with a BOM to CSS", () async {
    await d.file("test.scss", "\uFEFF\$color: red;").create();

    var sass = await runSass(["test.scss"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  // On Windows, this verifies that we don't consider the colon after a drive
  // letter to be an `input:output` separator.
  test("compiles an absolute Sass file to CSS", () async {
    await d.file("test.scss", "a {b: 1 + 2}").create();

    var sass = await runSass([p.absolute(d.path("test.scss"))]);
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

    var sass = await runSass(["--no-source-map", "test.scss", "out.css"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
    await d.file("out.css", equalsIgnoringWhitespace("a { b: 3; }")).validate();
  });

  test("creates directories if necessary", () async {
    await d.file("test.scss", "a {b: 1 + 2}").create();

    var sass =
        await runSass(["--no-source-map", "test.scss", "some/new/dir/out.css"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
    await d
        .file("some/new/dir/out.css", equalsIgnoringWhitespace("a { b: 3; }"))
        .validate();
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

    test("from SASS_PATH", () async {
      await d.file("test.scss", """
        @import 'test2';
        @import 'test3';
      """).create();

      await d.dir("dir2", [d.file("test2.scss", "a {b: c}")]).create();
      await d.dir("dir3", [d.file("test3.scss", "x {y: z}")]).create();

      var separator = Platform.isWindows ? ';' : ':';
      await expectCompiles(
          ["test.scss"], equalsIgnoringWhitespace("a { b: c; } x { y: z; }"),
          environment: {"SASS_PATH": "dir2${separator}dir3"});
    });

    // Regression test for #369
    test("from within a directory, relative to a file on the load path",
        () async {
      await d.dir(
          "dir1", [d.file("test.scss", "@import 'subdir/test2'")]).create();

      await d.dir("dir2", [
        d.dir("subdir", [
          d.file("test2.scss", "@import 'test3'"),
          d.file("test3.scss", "a {b: c}")
        ])
      ]).create();

      await expectCompiles(["--load-path", "dir2", "dir1/test.scss"],
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

    test("from the load path in preference to from SASS_PATH", () async {
      await d.file("test.scss", "@import 'test2'").create();

      await d.dir("dir1", [d.file("test2.scss", "a {b: c}")]).create();
      await d.dir("dir2", [d.file("test2.scss", "x {y: z}")]).create();

      await expectCompiles(["--load-path", "dir2", "test.scss"],
          equalsIgnoringWhitespace("x { y: z; }"),
          environment: {"SASS_PATH": "dir1"});
    });

    test("in SASS_PATH order", () async {
      await d.file("test.scss", "@import 'test2'").create();

      await d.dir("dir1", [d.file("test2.scss", "a {b: c}")]).create();
      await d.dir("dir2", [d.file("test2.scss", "x {y: z}")]).create();

      var separator = Platform.isWindows ? ';' : ':';
      await expectCompiles(
          ["test.scss"], equalsIgnoringWhitespace("x { y: z; }"),
          environment: {"SASS_PATH": "dir2${separator}dir3"});
    });

    // Regression test for an internal Google issue.
    test("multiple times from different load paths", () async {
      await d.file("test.scss", """
        @import 'parent/child/test2';
        @import 'child/test2';
      """).create();

      await d.dir("grandparent", [
        d.dir("parent", [
          d.dir("child", [
            d.file("test2.scss", "@import 'test3';"),
            d.file("test3.scss", "a {b: c};")
          ])
        ])
      ]).create();

      await expectCompiles([
        "--load-path",
        "grandparent",
        "--load-path",
        "grandparent/parent",
        "test.scss"
      ], equalsIgnoringWhitespace("a { b: c; } a { b: c; }"));
    });

    // Regression test for sass/dart-sass#899
    test("with both @use and @import", () async {
      await d.file("test.scss", """
        @use 'library';
        @import 'library';
      """).create();

      await d.dir("load-path", [
        d.file("_library.scss", "a { b: regular }"),
        d.file("_library.import.scss", "a { b: import-only }")
      ]).create();

      await expectCompiles(["--load-path", "load-path", "test.scss"],
          equalsIgnoringWhitespace("a { b: regular; } a { b: import-only; }"));
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
      var sass = await runSass(["--no-source-map", "--stdin", "out.css"]);
      sass.stdin.writeln("a {b: 1 + 2}");
      sass.stdin.close();
      expect(sass.stdout, emitsDone);

      await sass.shouldExit(0);
      await d
          .file("out.css", equalsIgnoringWhitespace("a { b: 3; }"))
          .validate();
    });

    test("uses the indented syntax with --indented", () async {
      var sass = await runSass(["--no-source-map", "--stdin", "--indented"]);
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

    // Regression test.
    test("supports @debug", () async {
      var sass = await runSass(["--no-source-map", "--stdin"]);
      sass.stdin.writeln("@debug foo");
      sass.stdin.close();
      expect(sass.stderr, emitsInOrder(["-:1 DEBUG: foo"]));
      await sass.shouldExit(0);
    });
  });

  test("gracefully reports errors from stdin", () async {
    var sass = await runSass(["--no-unicode", "-"]);
    sass.stdin.writeln("a {b: 1 + }");
    sass.stdin.close();
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: Expected expression.",
          "  ,",
          "1 | a {b: 1 + }",
          "  |           ^",
          "  '",
          "  - 1:11  root stylesheet",
        ]));
    await sass.shouldExit(65);
  });

  // Regression test for an issue mentioned in sass/linter#15
  test(
      "gracefully reports errors for binary operations with parentheized "
      "operands", () async {
    var sass = await runSass(["--no-unicode", "-"]);
    sass.stdin.writeln("a {b: (#123) + (#456)}");
    sass.stdin.close();
    expect(
        sass.stderr,
        emitsInOrder([
          'Error: Undefined operation "#123 + #456".',
          "  ,",
          "1 | a {b: (#123) + (#456)}",
          "  |       ^^^^^^^^^^^^^^^",
          "  '",
          "  - 1:7  root stylesheet",
        ]));
    await sass.shouldExit(65);
  });

  test("gracefully handles a non-partial next to a partial", () async {
    await d.file("test.scss", "a {b: c}").create();
    await d.file("_test.scss", "x {y: z}").create();

    var sass = await runSass(["test.scss"]);
    expect(
        sass.stdout,
        emitsInOrder([
          "a {",
          "  b: c;",
          "}",
        ]));
    await sass.shouldExit(0);
  });

  test("emits warnings on standard error", () async {
    await d.file("test.scss", "@warn 'aw beans'").create();

    var sass = await runSass(["test.scss"]);
    expect(sass.stdout, emitsDone);
    expect(
        sass.stderr,
        emitsInOrder([
          "WARNING: aw beans",
          "    test.scss 1:1  root stylesheet",
        ]));
    await sass.shouldExit(0);
  });

  test("emits debug messages on standard error", () async {
    await d.file("test.scss", "@debug 'what the heck'").create();

    var sass = await runSass(["test.scss"]);
    expect(sass.stdout, emitsDone);
    expect(sass.stderr, emits("test.scss:1 DEBUG: what the heck"));
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

  group("with --charset", () {
    test("doesn't emit @charset for a pure-ASCII stylesheet", () async {
      await d.file("test.scss", "a {b: c}").create();

      var sass = await runSass(["test.scss"]);
      expect(
          sass.stdout,
          emitsInOrder([
            "a {",
            "  b: c;",
            "}",
          ]));
      await sass.shouldExit(0);
    });

    test("emits @charset with expanded output", () async {
      await d.file("test.scss", "a {b: 👭}").create();

      var sass = await runSass(["test.scss"]);
      expect(
          sass.stdout,
          emitsInOrder([
            "@charset \"UTF-8\";",
            "a {",
            "  b: 👭;",
            "}",
          ]));
      await sass.shouldExit(0);
    });

    test("emits a BOM with compressed output", () async {
      await d.file("test.scss", "a {b: 👭}").create();

      var sass = await runSass(
          ["--no-source-map", "--style=compressed", "test.scss", "test.css"]);
      await sass.shouldExit(0);

      // We can't verify this as a string because `dart:io` automatically trims
      // the BOM.
      var bomBytes = utf8.encode("\uFEFF");
      expect(
          File(p.join(d.sandbox, "test.css"))
              .readAsBytesSync()
              .sublist(0, bomBytes.length),
          equals(bomBytes));
    });
  });

  group("with --no-charset", () {
    test("doesn't emit @charset with expanded output", () async {
      await d.file("test.scss", "a {b: 👭}").create();

      var sass = await runSass(["--no-charset", "test.scss"]);
      expect(
          sass.stdout,
          emitsInOrder([
            "a {",
            "  b: 👭;",
            "}",
          ]));
      await sass.shouldExit(0);
    });

    test("doesn't emit a BOM with compressed output", () async {
      await d.file("test.scss", "a {b: 👭}").create();

      var sass = await runSass([
        "--no-charset",
        "--no-source-map",
        "--style=compressed",
        "test.scss",
        "test.css"
      ]);
      await sass.shouldExit(0);

      // We can't verify this as a string because `dart:io` automatically trims
      // the BOM.
      var bomBytes = utf8.encode("\uFEFF");
      expect(
          File(p.join(d.sandbox, "test.css"))
              .readAsBytesSync()
              .sublist(0, bomBytes.length),
          isNot(equals(bomBytes)));
    });
  });

  group("with --error-css", () {
    var message = "Error: Expected expression.";
    setUp(() => d.file("test.scss", "a {b: 1 + }").create());

    group("not explicitly set", () {
      test("doesn't emit error CSS when compiling to stdout", () async {
        var sass = await runSass(["test.scss"]);
        expect(sass.stdout, emitsDone);
        await sass.shouldExit(65);
      });

      test("emits error CSS when compiling to a file", () async {
        var sass = await runSass(["test.scss", "test.css"]);
        await sass.shouldExit(65);
        await d.file("test.css", contains(message)).validate();
      });
    });

    group("explicitly set", () {
      test("emits error CSS when compiling to stdout", () async {
        var sass = await runSass(["--error-css", "test.scss"]);
        expect(sass.stdout, emitsThrough(contains(message)));
        await sass.shouldExit(65);
      });

      test("emits error CSS when compiling to a file", () async {
        var sass = await runSass(["--error-css", "test.scss", "test.css"]);
        await sass.shouldExit(65);
        await d.file("test.css", contains(message)).validate();
      });
    });

    group("explicitly unset", () {
      test("doesn't emit error CSS when compiling to stdout", () async {
        var sass = await runSass(["--no-error-css", "test.scss"]);
        expect(sass.stdout, emitsDone);
        await sass.shouldExit(65);
      });

      test("emits error CSS when compiling to a file", () async {
        var sass = await runSass(["--no-error-css", "test.scss", "test.css"]);
        await sass.shouldExit(65);
        await d.nothing("test.css").validate();
      });
    });
  });
}
