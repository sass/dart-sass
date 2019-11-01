// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import '../../utils.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  Future<TestProcess> update(Iterable<String> arguments) =>
      runSass(["--no-source-map", "--update", ...arguments]);

  group("updates CSS", () {
    test("that doesn't exist yet", () async {
      await d.file("test.scss", "a {b: c}").create();

      var sass = await update(["test.scss:out.css"]);
      expect(sass.stdout, emits('Compiled test.scss to out.css.'));
      await sass.shouldExit(0);

      await d
          .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
          .validate();
    });

    test("whose source was modified", () async {
      await d.file("out.css", "x {y: z}").create();
      await tick;
      await d.file("test.scss", "a {b: c}").create();

      var sass = await update(["test.scss:out.css"]);
      expect(sass.stdout, emits('Compiled test.scss to out.css.'));
      await sass.shouldExit(0);

      await d
          .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
          .validate();
    });

    test("whose source was transitively modified", () async {
      await d.file("other.scss", "a {b: c}").create();
      await d.file("test.scss", "@import 'other'").create();

      var sass = await update(["test.scss:out.css"]);
      expect(sass.stdout, emits('Compiled test.scss to out.css.'));
      await sass.shouldExit(0);

      await tick;
      await d.file("other.scss", "x {y: z}").create();

      sass = await update(["test.scss:out.css"]);
      expect(sass.stdout, emits('Compiled test.scss to out.css.'));
      await sass.shouldExit(0);

      await d
          .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
          .validate();
    });

    test("files that share a modified import", () async {
      await d.file("other.scss", r"a {b: $var}").create();
      await d.file("test1.scss", r"$var: 1; @import 'other'").create();
      await d.file("test2.scss", r"$var: 2; @import 'other'").create();

      var sass = await update(["test1.scss:out1.css", "test2.scss:out2.css"]);
      expect(sass.stdout, emits('Compiled test1.scss to out1.css.'));
      expect(sass.stdout, emits('Compiled test2.scss to out2.css.'));
      await sass.shouldExit(0);

      await tick;
      await d.file("other.scss", r"x {y: $var}").create();

      sass = await update(["test1.scss:out1.css", "test2.scss:out2.css"]);
      expect(sass.stdout, emits('Compiled test1.scss to out1.css.'));
      expect(sass.stdout, emits('Compiled test2.scss to out2.css.'));
      await sass.shouldExit(0);

      await d
          .file("out1.css", equalsIgnoringWhitespace("x { y: 1; }"))
          .validate();
      await d
          .file("out2.css", equalsIgnoringWhitespace("x { y: 2; }"))
          .validate();
    });

    test("from stdin", () async {
      var sass = await update(["-:out.css"]);
      sass.stdin.writeln("a {b: c}");
      sass.stdin.close();
      expect(sass.stdout, emits('Compiled stdin to out.css.'));
      await sass.shouldExit(0);

      await d
          .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
          .validate();

      sass = await update(["-:out.css"]);
      sass.stdin.writeln("x {y: z}");
      sass.stdin.close();
      expect(sass.stdout, emits('Compiled stdin to out.css.'));
      await sass.shouldExit(0);

      await d
          .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
          .validate();
    });

    test("without printing anything if --quiet is passed", () async {
      await d.file("test.scss", "a {b: c}").create();

      var sass = await update(["--quiet", "test.scss:out.css"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d
          .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
          .validate();
    });
  });

  group("doesn't update a CSS file", () {
    test("whose sources weren't modified", () async {
      await d.file("test.scss", "a {b: c}").create();
      await d.file("out.css", "x {y: z}").create();

      var sass = await update(["test.scss:out.css"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.file("out.css", "x {y: z}").validate();
    });

    test("whose sibling was modified", () async {
      await d.file("test1.scss", "a {b: c}").create();
      await d.file("out1.css", "x {y: z}").create();

      await d.file("out2.css", "q {r: s}").create();
      await tick;
      await d.file("test2.scss", "d {e: f}").create();

      var sass = await update(["test1.scss:out1.css", "test2.scss:out2.css"]);
      expect(sass.stdout, emits('Compiled test2.scss to out2.css.'));
      await sass.shouldExit(0);

      await d.file("out1.css", "x {y: z}").validate();
    });

    test("with a missing import", () async {
      await d.file("test.scss", "@import 'other'").create();

      var message = "Error: Can't find stylesheet to import.";
      var sass = await update(["test.scss:out.css"]);
      expect(sass.stderr, emits(message));
      expect(sass.stderr, emitsThrough(contains("test.scss 1:9")));
      await sass.shouldExit(65);

      await d.file("out.css", contains(message)).validate();
    });

    test("with a conflicting import", () async {
      await d.file("test.scss", "@import 'other'").create();
      await d.file("other.scss", "a {b: c}").create();
      await d.file("_other.scss", "x {y: z}").create();

      var message = "Error: It's not clear which file to import. Found:";
      var sass = await update(["test.scss:out.css"]);
      expect(sass.stderr, emits(message));
      expect(sass.stderr, emitsThrough(contains("test.scss 1:9")));
      await sass.shouldExit(65);

      await d.file("out.css", contains(message)).validate();
    });

    test("from itself", () async {
      await d.dir("dir", [d.file("test.css", "a {b: c}")]).create();

      var sass = await update(["dir:dir"]);
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);

      await d.file("dir/test.css", "a {b: c}").validate();
    });
  });

  group("updates a CSS file", () {
    test("when a file has an error", () async {
      await d.file("test.scss", "a {b: c}").create();
      await (await update(["test.scss:out.css"])).shouldExit(0);
      await d.file("out.css", anything).validate();

      var message = "Error: Expected expression.";
      await d.file("test.scss", "a {b: }").create();
      var sass = await update(["test.scss:out.css"]);
      expect(sass.stderr, emits(message));
      expect(sass.stderr, emitsThrough(contains("test.scss 1:7")));
      await sass.shouldExit(65);

      await d.file("out.css", contains(message)).validate();
    });

    test("when a file has an error even with another stdout output", () async {
      await d.file("test.scss", "a {b: c}").create();
      await (await update(["test.scss:out.css"])).shouldExit(0);
      await d.file("out.css", anything).validate();

      var message = "Error: Expected expression.";
      await d.file("test.scss", "a {b: }").create();
      await d.file("other.scss", "x {y: z}").create();
      var sass = await update(["test.scss:out.css", "other.scss:-"]);
      expect(sass.stderr, emits(message));
      expect(sass.stderr, emitsThrough(contains("test.scss 1:7")));
      await sass.shouldExit(65);

      await d.file("out.css", contains(message)).validate();
    });

    test("when an import is removed", () async {
      await d.file("test.scss", "@import 'other'").create();
      await d.file("_other.scss", "a {b: c}").create();
      await (await update(["test.scss:out.css"])).shouldExit(0);
      await d.file("out.css", anything).validate();

      var message = "Error: Can't find stylesheet to import.";
      d.file("_other.scss").io.deleteSync();
      var sass = await update(["test.scss:out.css"]);
      expect(sass.stderr, emits(message));
      expect(sass.stderr, emitsThrough(contains("test.scss 1:9")));
      await sass.shouldExit(65);

      await d.file("out.css", contains(message)).validate();
    });
  });

  test("deletes a CSS file when a file has an error with --no-error-css",
      () async {
    await d.file("test.scss", "a {b: c}").create();
    await (await update(["test.scss:out.css"])).shouldExit(0);
    await d.file("out.css", anything).validate();

    await d.file("test.scss", "a {b: }").create();
    var sass = await update(["--no-error-css", "test.scss:out.css"]);
    expect(sass.stderr, emits("Error: Expected expression."));
    expect(sass.stderr, emitsThrough(contains("test.scss 1:7")));
    await sass.shouldExit(65);

    await d.nothing("out.css").validate();
  });

  group("doesn't allow", () {
    test("--stdin", () async {
      var sass = await update(["--stdin", "test.scss"]);
      expect(sass.stdout, emits('--update is not allowed with --stdin.'));
      await sass.shouldExit(64);
    });

    test("printing to stderr", () async {
      var sass = await update(["test.scss"]);
      expect(sass.stdout,
          emits('--update is not allowed when printing to stdout.'));
      await sass.shouldExit(64);
    });
  });
}
