// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:dart2_constant/convert.dart' as convert;
import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'package:sass/sass.dart' as sass;
import 'package:sass/src/io.dart';

import 'utils.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  /// Runs the executable on [arguments] plus an output file, then verifies that
  /// the contents of the output file match [expected].
  Future expectCompiles(List<String> arguments, expected) async {
    var sass = await runSass(
        arguments.toList()..add("out.css")..add("--no-source-map"));
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
  });

  group("with colon arguments", () {
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
        var sass =
            await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
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

        var sass =
            await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
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

        var sass =
            await runSass(["test1.scss:out1.css", "test2.scss:out2.css"]);
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
      });

      test("--stdin", () async {
        var sass = await runSass(["--stdin", "test.scss:out.css"]);
        expect(
            sass.stdout, emits('--stdin may not be used with ":" arguments.'));
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
  });

  group("with --update", () {
    group("updates CSS", () {
      test("that doesn't exist yet", () async {
        await d.file("test.scss", "a {b: c}").create();

        var sass =
            await runSass(["--no-source-map", "--update", "test.scss:out.css"]);
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

        var sass =
            await runSass(["--no-source-map", "--update", "test.scss:out.css"]);
        expect(sass.stdout, emits('Compiled test.scss to out.css.'));
        await sass.shouldExit(0);

        await d
            .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
            .validate();
      });

      test("whose source was transitively modified", () async {
        await d.file("other.scss", "a {b: c}").create();
        await d.file("test.scss", "@import 'other'").create();

        var sass =
            await runSass(["--no-source-map", "--update", "test.scss:out.css"]);
        expect(sass.stdout, emits('Compiled test.scss to out.css.'));
        await sass.shouldExit(0);

        await tick;
        await d.file("other.scss", "x {y: z}").create();

        sass =
            await runSass(["--no-source-map", "--update", "test.scss:out.css"]);
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

        var sass = await runSass([
          "--no-source-map",
          "--update",
          "test1.scss:out1.css",
          "test2.scss:out2.css"
        ]);
        expect(sass.stdout, emits('Compiled test1.scss to out1.css.'));
        expect(sass.stdout, emits('Compiled test2.scss to out2.css.'));
        await sass.shouldExit(0);

        await tick;
        await d.file("other.scss", r"x {y: $var}").create();

        sass = await runSass([
          "--no-source-map",
          "--update",
          "test1.scss:out1.css",
          "test2.scss:out2.css"
        ]);
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
        var sass = await runSass(["--no-source-map", "--update", "-:out.css"]);
        sass.stdin.writeln("a {b: c}");
        sass.stdin.close();
        expect(sass.stdout, emits('Compiled stdin to out.css.'));
        await sass.shouldExit(0);

        await d
            .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
            .validate();

        sass = await runSass(["--no-source-map", "--update", "-:out.css"]);
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

        var sass = await runSass(
            ["--no-source-map", "--update", "--quiet", "test.scss:out.css"]);
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

        var sass =
            await runSass(["--no-source-map", "--update", "test.scss:out.css"]);
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

        var sass = await runSass([
          "--no-source-map",
          "--update",
          "test1.scss:out1.css",
          "test2.scss:out2.css"
        ]);
        expect(sass.stdout, emits('Compiled test2.scss to out2.css.'));
        await sass.shouldExit(0);

        await d.file("out1.css", "x {y: z}").validate();
      });
    });

    group("doesn't allow", () {
      test("--stdin", () async {
        var sass = await runSass(
            ["--no-source-map", "--stdin", "--update", "test.scss"]);
        expect(sass.stdout, emits('--update is not allowed with --stdin.'));
        await sass.shouldExit(64);
      });

      test("printing to stderr", () async {
        var sass = await runSass(["--no-source-map", "--update", "test.scss"]);
        expect(sass.stdout,
            emits('--update is not allowed when printing to stdout.'));
        await sass.shouldExit(64);
      });
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

  group("source maps:", () {
    group("for a simple compilation", () {
      Map<String, Object> map;
      setUp(() async {
        await d.file("test.scss", "a {b: 1 + 2}").create();

        await (await runSass(["test.scss", "out.css"])).shouldExit(0);
        map = _readJson("out.css.map");
      });

      test("refers to the source file", () {
        expect(map, containsPair("sources", ["test.scss"]));
      });

      test("refers to the target file", () {
        expect(map, containsPair("file", "out.css"));
      });

      test("contains mappings", () {
        SingleMapping sourceMap;
        sass.compileString("a {b: 1 + 2}", sourceMap: (map) => sourceMap = map);
        expect(map, containsPair("mappings", sourceMap.toJson()["mappings"]));
      });
    });

    group("with multiple sources", () {
      setUp(() async {
        await d.file("test.scss", """
        @import 'dir/other';
        x {y: z}
      """).create();
        await d.dir("dir", [d.file("other.scss", "a {b: 1 + 2}")]).create();
      });

      test("refers to them using relative URLs by default", () async {
        await (await runSass(["test.scss", "out.css"])).shouldExit(0);
        expect(_readJson("out.css.map"),
            containsPair("sources", ["dir/other.scss", "test.scss"]));
      });

      test("refers to them using relative URLs with --source-map-urls=relative",
          () async {
        await (await runSass(
                ["--source-map-urls=relative", "test.scss", "out.css"]))
            .shouldExit(0);
        expect(_readJson("out.css.map"),
            containsPair("sources", ["dir/other.scss", "test.scss"]));
      });

      test("refers to them using absolute URLs with --source-map-urls=absolute",
          () async {
        await (await runSass(
                ["--source-map-urls=absolute", "test.scss", "out.css"]))
            .shouldExit(0);
        expect(
            _readJson("out.css.map"),
            containsPair("sources", [
              p
                  .toUri(p.canonicalize(p.join(d.sandbox, "dir/other.scss")))
                  .toString(),
              p.toUri(p.canonicalize(p.join(d.sandbox, "test.scss"))).toString()
            ]));
      });

      test("includes source contents with --embed-sources", () async {
        await (await runSass(["--embed-sources", "test.scss", "out.css"]))
            .shouldExit(0);
        expect(
            _readJson("out.css.map"),
            containsPair("sourcesContent",
                ["a {b: 1 + 2}", readFile(p.join(d.sandbox, "test.scss"))]));
      });
    });

    test("refers to a source in another directory", () async {
      await d.dir("in", [d.file("test.scss", "x {y: z}")]).create();
      await (await runSass(["in/test.scss", "out/test.css"])).shouldExit(0);
      expect(_readJson("out/test.css.map"),
          containsPair("sources", ["../in/test.scss"]));
    });

    test("includes a source map comment", () async {
      await d.file("test.scss", "a {b: c}").create();
      await (await runSass(["test.scss", "out.css"])).shouldExit(0);
      await d
          .file(
              "out.css", endsWith("\n\n/*# sourceMappingURL=out.css.map */\n"))
          .validate();
    });

    test("with --stdin uses an empty string", () async {
      var sass = await runSass(["--stdin", "out.css"]);
      sass.stdin.writeln("a {b: c}");
      sass.stdin.close();
      await sass.shouldExit(0);

      expect(_readJson("out.css.map"), containsPair("sources", [""]));
    });

    group("with --no-source-map,", () {
      setUp(() async {
        await d.file("test.scss", "a {b: c}").create();
      });

      test("no source map is generated", () async {
        await (await runSass(["--no-source-map", "test.scss", "out.css"]))
            .shouldExit(0);

        await d.file("out.css", isNot(contains("/*#"))).validate();
        await d.nothing("out.css.map").validate();
      });

      test("--source-map-urls is disallowed", () async {
        var sass = await runSass([
          "--no-source-map",
          "--source-map-urls=absolute",
          "test.scss",
          "out.css"
        ]);
        expect(sass.stdout,
            emits("--source-map-urls isn't allowed with --no-source-map."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });

      test("--embed-sources is disallowed", () async {
        var sass = await runSass(
            ["--no-source-map", "--embed-sources", "test.scss", "out.css"]);
        expect(sass.stdout,
            emits("--embed-sources isn't allowed with --no-source-map."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });

      test("--embed-source-map is disallowed", () async {
        var sass = await runSass(
            ["--no-source-map", "--embed-source-map", "test.scss", "out.css"]);
        expect(sass.stdout,
            emits("--embed-source-map isn't allowed with --no-source-map."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });
    });

    group("when emitting to stdout", () {
      test("--source-map isn't allowed", () async {
        await d.file("test.scss", "a {b: c}").create();
        var sass = await runSass(["--source-map", "test.scss"]);
        expect(
            sass.stdout,
            emits("When printing to stdout, --source-map requires "
                "--embed-source-map."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });

      test("--source-map-urls is disallowed", () async {
        await d.file("test.scss", "a {b: c}").create();
        var sass = await runSass(["--source-map-urls=absolute", "test.scss"]);
        expect(
            sass.stdout,
            emits("When printing to stdout, --source-map-urls requires "
                "--embed-source-map."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });

      test("--embed-sources is disallowed", () async {
        await d.file("test.scss", "a {b: c}").create();
        var sass = await runSass(["--embed-sources", "test.scss"]);
        expect(
            sass.stdout,
            emits("When printing to stdout, --embed-sources requires "
                "--embed-source-map."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });

      test(
          "--source-map-urls=relative is disallowed even with "
          "--embed-source-map", () async {
        await d.file("test.scss", "a {b: c}").create();
        var sass = await runSass(
            ["--source-map-urls=relative", "--embed-source-map", "test.scss"]);
        expect(
            sass.stdout,
            emits("--source-map-urls=relative isn't allowed when printing to "
                "stdout."));
        expect(sass.stdout,
            emitsThrough(contains("Print this usage information.")));
        await sass.shouldExit(64);
      });

      test("everything is allowed with --embed-source-map", () async {
        await d.file("test.scss", "a {b: c}").create();
        var sass = await runSass([
          "--source-map",
          "--source-map-urls=absolute",
          "--embed-sources",
          "--embed-source-map",
          "test.scss"
        ]);
        var css = (await sass.stdout.rest.toList()).join("\n");
        await sass.shouldExit(0);

        var map = embeddedSourceMap(css);
        expect(map, isNotEmpty);
        expect(map, isNot(contains("file")));
      });
    });

    group("with --embed-source-map", () {
      setUp(() async {
        await d.file("test.scss", "a {b: 1 + 2}").create();
      });

      Map<String, Object> map;
      group("with the target in the same directory", () {
        setUp(() async {
          await (await runSass(["--embed-source-map", "test.scss", "out.css"]))
              .shouldExit(0);
          var css = readFile(p.join(d.sandbox, "out.css"));
          map = embeddedSourceMap(css);
        });

        test("contains mappings in the generated CSS", () {
          SingleMapping sourceMap;
          sass.compileString("a {b: 1 + 2}",
              sourceMap: (map) => sourceMap = map);
          expect(map, containsPair("mappings", sourceMap.toJson()["mappings"]));
        });

        test("refers to the source file", () {
          expect(map, containsPair("sources", ["test.scss"]));
        });

        test("refers to the target file", () {
          expect(map, containsPair("file", "out.css"));
        });

        test("doesn't generate a source map file", () async {
          await d.nothing("out.css.map").validate();
        });
      });

      group("with the target in a different directory", () {
        setUp(() async {
          await ensureDir(p.join(d.sandbox, "dir"));
          await (await runSass(
                  ["--embed-source-map", "test.scss", "dir/out.css"]))
              .shouldExit(0);
          var css = readFile(p.join(d.sandbox, "dir/out.css"));
          map = embeddedSourceMap(css);
        });

        test("refers to the source file", () {
          expect(map, containsPair("sources", ["../test.scss"]));
        });

        test("refers to the target file", () {
          expect(map, containsPair("file", "out.css"));
        });
      });
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

    test("from invalid arguments with --interactive", () async {
      var invalidArgs = [
        '--stdin',
        '--indented',
        '--load-path=x',
        '--style=compressed',
        '--source-map',
        '--source-map-urls=absolute',
        '--embed-sources',
        '--embed-source-map'
      ];
      for (var arg in invalidArgs) {
        var sass = await runSass(["--interactive", arg]);
        expect(sass.stdout,
            emitsThrough(contains("isn't allowed with --interactive")));
        sass.stdin.close();
        await sass.shouldExit(64);
      }
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

  group("--interactive", () {
    test("works with no input", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.close();
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);
    });

    test("works for expressions", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("4 + 5");
      sass.stdin.close();
      expect(sass.stdout, emitsInOrder([">> 4 + 5", "9"]));
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);
    });

    test("works for declarations", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln(r"$x: 6");
      sass.stdin.close();
      expect(sass.stdout, emitsInOrder([r">> $x: 6", "6"]));
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);
    });

    test("works for variable usage", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln(r"$x: 4");
      sass.stdin.writeln(r"$x * 2");
      sass.stdin.close();
      expect(sass.stdout, emitsInOrder([r">> $x: 4", "4", r">> $x * 2", "8"]));
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);
    });

    test("ignores empty lines", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("");
      sass.stdin.writeln("  ");
      sass.stdin.close();
      expect(sass.stdout, emitsInOrder([">> ", ">>   "]));
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);
    });

    test("logs proper errors", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("1 + 2;");
      sass.stdin.writeln("max(2, 1 + blue)");
      sass.stdin.writeln(r"1 + $x + 3");
      sass.stdin.writeln("foo(");
      sass.stdin.writeln("call('max', 1, 2) + blue");
      sass.stdin.close();
      expect(
          sass.stdout,
          emitsInOrder([
            ">> 1 + 2;",
            "        ^",
            "Error: expected no more input.",
            ">> max(2, 1 + blue)",
            "          ^^^^^^^^",
            'Error: Undefined operation "1 + blue".',
            r">> 1 + $x + 3",
            r"       ^^",
            "Error: Undefined variable.",
            ">> foo(",
            "       ^",
            'Error: expected ")".',
            ">> call('max', 1, 2) + blue",
            'Error: Undefined operation "2 + blue".',
            "call('max', 1, 2) + blue",
            "^^^^^^^^^^^^^^^^^^^^^^^^"
          ]));
      expect(sass.stdout, emitsDone);
      expect(sass.stderr, emitsThrough(contains("DEPRECATION WARNING")));
      await sass.shouldExit(0);
    });

    test("logs proper errors with color", () async {
      var sass = await runSass(["--interactive", "--color"]);
      sass.stdin.writeln("1 + 2;");
      sass.stdin.writeln("max(2, 1 + blue)");
      sass.stdin.writeln(r"1 + $x + 3");
      sass.stdin.writeln("foo(");
      sass.stdin.close();
      expect(
          sass.stdout,
          emitsInOrder([
            ">> 1 + 2;",
            "\u001b[31m\u001b[1F\u001b[8C;",
            "        ^",
            "\u001b[0mError: expected no more input.",
            ">> max(2, 1 + blue)",
            "\u001b[31m\u001b[1F\u001b[10C1 + blue",
            "          ^^^^^^^^",
            '\u001b[0mError: Undefined operation "1 + blue".',
            r">> 1 + $x + 3",
            "\u001b[31m\u001b[1F\u001b[7C\$x",
            r"       ^^",
            "\u001b[0mError: Undefined variable.",
            ">> foo(",
            "\u001b[31m       ^",
            '\u001b[0mError: expected ")".'
          ]));
      expect(sass.stdout, emitsDone);
      await sass.shouldExit(0);
    });
  });
}

/// Reads the file at [path] within [d.sandbox] and JSON-decodes it.
Map<String, Object> _readJson(String path) =>
    convert.json.decode(readFile(p.join(d.sandbox, path)))
        as Map<String, Object>;
