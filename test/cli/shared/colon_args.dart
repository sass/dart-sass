// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  test("compiles multiple sources to multiple destinations", () async {
    await d.file("test1.scss", "a {b: c}").create();
    await d.file("test2.scss", "x {y: z}").create();

    var sass = await runSass(
        ["--no-source-map", "test1.scss:out1.css", "test2.scss:out2.css"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);

    await d
        .file("out1.css", equalsIgnoringWhitespace("a { b: c; }"))
        .validate();
    await d
        .file("out2.css", equalsIgnoringWhitespace("x { y: z; }"))
        .validate();
  });

  // On Windows, this verifies that we don't consider the colon after a drive
  // letter to be an `input:output` separator.
  test("compiles an absolute source to an absolute destination", () async {
    await d.file("test.scss", "a {b: c}").create();

    var input = p.absolute(d.path('test.scss'));
    var output = p.absolute(d.path('out.css'));
    var sass = await runSass(["--no-source-map", "$input:$output"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);

    await d.file("out.css", equalsIgnoringWhitespace("a { b: c; }")).validate();
  });

  test("creates destination directories", () async {
    await d.file("test.scss", "a {b: c}").create();

    var sass = await runSass(["--no-source-map", "test.scss:dir/out.css"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);

    await d.dir("dir", [
      d.file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
    ]).validate();
  });

  test("creates source maps for each compilation", () async {
    await d.file("test1.scss", "a {b: c}").create();
    await d.file("test2.scss", "x {y: z}").create();

    var sass = await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);

    await d.file("out1.css", contains("out1.css.map")).validate();
    await d.file("out1.css.map", contains("test1.scss")).validate();
    await d.file("out2.css", contains("out2.css.map")).validate();
    await d.file("out2.css.map", contains("test2.scss")).validate();
  });

  test("continues compiling after an error", () async {
    await d.file("test1.scss", "a {b: }").create();
    await d.file("test2.scss", "x {y: z}").create();

    var sass = await runSass(
        ["--no-source-map", "test1.scss:out1.css", "test2.scss:out2.css"]);
    await expectLater(sass.stderr, emits('Error: Expected expression.'));
    await expectLater(sass.stderr, emitsThrough(contains('test1.scss 1:7')));
    await sass.shouldExit(65);

    await d.nothing("out1.css").validate();
    await d
        .file("out2.css", equalsIgnoringWhitespace("x { y: z; }"))
        .validate();
  });

  test("stops compiling after an error with --stop-on-error", () async {
    await d.file("test1.scss", "a {b: }").create();
    await d.file("test2.scss", "x {y: z}").create();

    var sass = await runSass(
        ["--stop-on-error", "test1.scss:out1.css", "test2.scss:out2.css"]);
    await expectLater(
        sass.stderr,
        emitsInOrder([
          'Error: Expected expression.',
          emitsThrough(contains('test1.scss 1:7')),
          emitsDone
        ]));
    await sass.shouldExit(65);

    await d.nothing("out1.css").validate();
    await d.nothing("out2.css").validate();
  });

  group("with a directory argument", () {
    test("compiles all the stylesheets in the directory", () async {
      await d.dir("in", [
        d.file("test1.scss", "a {b: c}"),
        d.file("test2.sass", "x\n  y: z")
      ]).create();

      var sass = await runSass(["--no-source-map", "in:out"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.dir("out", [
        d.file("test1.css", equalsIgnoringWhitespace("a { b: c; }")),
        d.file("test2.css", equalsIgnoringWhitespace("x { y: z; }"))
      ]).validate();
    });

    test("creates subdirectories in the destination", () async {
      await d.dir("in", [
        d.dir("sub", [d.file("test.scss", "a {b: c}")])
      ]).create();

      var sass = await runSass(["--no-source-map", "in:out"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.dir("out", [
        d.dir("sub",
            [d.file("test.css", equalsIgnoringWhitespace("a { b: c; }"))])
      ]).validate();
    });

    test("compiles files to the same directory if no output is given",
        () async {
      await d.dir("in", [
        d.file("test1.scss", "a {b: c}"),
        d.file("test2.sass", "x\n  y: z")
      ]).create();

      var sass = await runSass(["--no-source-map", "in"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.dir("in", [
        d.file("test1.css", equalsIgnoringWhitespace("a { b: c; }")),
        d.file("test2.css", equalsIgnoringWhitespace("x { y: z; }"))
      ]).validate();
    });

    test("ignores partials", () async {
      await d.dir("in", [
        d.file("_fake.scss", "a {b:"),
        d.file("real.scss", "x {y: z}")
      ]).create();

      var sass = await runSass(["--no-source-map", "in:out"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.dir("out", [
        d.file("real.css", equalsIgnoringWhitespace("x { y: z; }")),
        d.nothing("fake.css"),
        d.nothing("_fake.css")
      ]).validate();
    });

    test("ignores files without a Sass extension", () async {
      await d.dir("in", [
        d.file("fake.szss", "a {b:"),
        d.file("real.scss", "x {y: z}")
      ]).create();

      var sass = await runSass(["--no-source-map", "in:out"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.dir("out", [
        d.file("real.css", equalsIgnoringWhitespace("x { y: z; }")),
        d.nothing("fake.css")
      ]).validate();
    });
  });

  group("reports all", () {
    test("file-not-found errors", () async {
      var sass = await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
      expect(
          sass.stderr,
          emitsInOrder([
            startsWith("Error reading test1.scss: "),
            "",
            startsWith("Error reading test2.scss: ")
          ]));
      await sass.shouldExit(66);
    });

    test("compilation errors", () async {
      await d.file("test1.scss", "a {b: }").create();
      await d.file("test2.scss", "x {y: }").create();

      var sass = await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
      expect(
          sass.stderr,
          emitsInOrder([
            "Error: Expected expression.",
            "a {b: }",
            "      ^",
            "  test1.scss 1:7  root stylesheet",
            "",
            "Error: Expected expression.",
            "x {y: }",
            "      ^",
            "  test2.scss 1:7  root stylesheet"
          ]));
      await sass.shouldExit(65);
    });

    test("runtime errors", () async {
      await d.file("test1.scss", "a {b: 1 + #abc}").create();
      await d.file("test2.scss", "x {y: 1 + #abc}").create();

      var sass = await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
      expect(
          sass.stderr,
          emitsInOrder([
            'Error: Undefined operation "1 + #abc".',
            "a {b: 1 + #abc}",
            "      ^^^^^^^^",
            "  test1.scss 1:7  root stylesheet",
            "",
            'Error: Undefined operation "1 + #abc".',
            "x {y: 1 + #abc}",
            "      ^^^^^^^^",
            "  test2.scss 1:7  root stylesheet"
          ]));
      await sass.shouldExit(65);
    });
  });

  group("doesn't allow", () {
    group("positional arguments", () {
      test("before", () async {
        var sass = await runSass(["positional", "test.scss:out.css"]);
        expect(sass.stdout,
            emits('Positional and ":" arguments may not both be used.'));
        await sass.shouldExit(64);
      });

      test("after", () async {
        var sass = await runSass(["test.scss:out.css", "positional"]);
        expect(sass.stdout,
            emits('Positional and ":" arguments may not both be used.'));
        await sass.shouldExit(64);
      });

      test("before a directory", () async {
        await d.dir("in").create();

        var sass = await runSass(["positional", "in"]);
        expect(
            sass.stdout, emits('Directory "in" may not be a positional arg.'));
        await sass.shouldExit(64);
      });

      test("after a directory", () async {
        await d.dir("in").create();

        var sass = await runSass(["in", "positional"]);
        expect(
            sass.stdout,
            emitsInOrder([
              'Directory "in" may not be a positional arg.',
              'To compile all CSS in "in" to "positional", use `sass '
                  'in:positional`.'
            ]));
        await sass.shouldExit(64);
      });
    });

    test("--stdin", () async {
      var sass = await runSass(["--stdin", "test.scss:out.css"]);
      expect(sass.stdout, emits('--stdin may not be used with ":" arguments.'));
      await sass.shouldExit(64);
    });

    test("multiple colons", () async {
      var sass = await runSass(["test.scss:out.css:wut"]);
      expect(sass.stdout,
          emits('"test.scss:out.css:wut" may only contain one ":".'));
      await sass.shouldExit(64);
    });

    test("duplicate sources", () async {
      var sass = await runSass(["test.scss:out1.css", "test.scss:out2.css"]);
      expect(sass.stdout, emits('Duplicate source "test.scss".'));
      await sass.shouldExit(64);
    });
  });
}
