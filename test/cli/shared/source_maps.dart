// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'package:sass/sass.dart' as sass;
import 'package:sass/src/io.dart';

import '../../utils.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
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
            p.toUri(p.canonicalize(d.path("dir/other.scss"))).toString(),
            p.toUri(p.canonicalize(d.path("test.scss"))).toString()
          ]));
    });

    test("includes source contents with --embed-sources", () async {
      await (await runSass(["--embed-sources", "test.scss", "out.css"]))
          .shouldExit(0);
      expect(
          _readJson("out.css.map"),
          containsPair("sourcesContent",
              ["a {b: 1 + 2}", readFile(d.path("test.scss"))]));
    });
  });

  group("doesn't normalize file case", () {
    setUp(() => d.file("TeSt.scss", "a {b: c}").create());

    test("when loaded with the same case", () async {
      await (await runSass(["TeSt.scss", "out.css"])).shouldExit(0);
      expect(_readJson("out.css.map"), containsPair("sources", ["TeSt.scss"]));
    });

    test("when imported with the same case", () async {
      await d.file("importer.scss", "@import 'TeSt.scss'").create();
      await (await runSass(["importer.scss", "out.css"])).shouldExit(0);
      expect(_readJson("out.css.map"), containsPair("sources", ["TeSt.scss"]));
    });

    // The following tests rely on Windows' case-insensitive filesystem.

    test("when loaded with a different case", () async {
      await (await runSass(["test.scss", "out.css"])).shouldExit(0);
      expect(_readJson("out.css.map"), containsPair("sources", ["TeSt.scss"]));
    }, testOn: "windows");

    test("when imported with a different case", () async {
      await d.file("importer.scss", "@import 'test.scss'").create();
      await (await runSass(["importer.scss", "out.css"])).shouldExit(0);
      expect(_readJson("out.css.map"), containsPair("sources", ["TeSt.scss"]));
    }, testOn: "windows");
  });

  test("includes a source map comment", () async {
    await d.file("test.scss", "a {b: c}").create();
    await (await runSass(["test.scss", "out.css"])).shouldExit(0);
    await d
        .file("out.css", endsWith("\n\n/*# sourceMappingURL=out.css.map */\n"))
        .validate();
  });

  group("in another directory", () {
    setUp(() async {
      await d.dir("in", [d.file("test.scss", "x {y: z}")]).create();
      await (await runSass(["in/test.scss", "out/test.css"])).shouldExit(0);
    });

    test("refers to a source", () {
      expect(_readJson("out/test.css.map"),
          containsPair("sources", ["../in/test.scss"]));
    });

    test("includes a source map comment", () async {
      await d
          .file("out/test.css",
              endsWith("\n\n/*# sourceMappingURL=test.css.map */\n"))
          .validate();
    });
  });

  test("with --stdin uses a data: URL", () async {
    var sass = await runSass(["--stdin", "out.css"]);
    sass.stdin.writeln("a {b: c}");
    sass.stdin.close();
    await sass.shouldExit(0);

    expect(
        _readJson("out.css.map"),
        containsPair("sources",
            [Uri.dataFromString("a {b: c}\n", encoding: utf8).toString()]));
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
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
      await sass.shouldExit(64);
    });

    test("--embed-sources is disallowed", () async {
      var sass = await runSass(
          ["--no-source-map", "--embed-sources", "test.scss", "out.css"]);
      expect(sass.stdout,
          emits("--embed-sources isn't allowed with --no-source-map."));
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
      await sass.shouldExit(64);
    });

    test("--embed-source-map is disallowed", () async {
      var sass = await runSass(
          ["--no-source-map", "--embed-source-map", "test.scss", "out.css"]);
      expect(sass.stdout,
          emits("--embed-source-map isn't allowed with --no-source-map."));
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
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
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
      await sass.shouldExit(64);
    });

    test("--source-map-urls is disallowed", () async {
      await d.file("test.scss", "a {b: c}").create();
      var sass = await runSass(["--source-map-urls=absolute", "test.scss"]);
      expect(
          sass.stdout,
          emits("When printing to stdout, --source-map-urls requires "
              "--embed-source-map."));
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
      await sass.shouldExit(64);
    });

    test("--embed-sources is disallowed", () async {
      await d.file("test.scss", "a {b: c}").create();
      var sass = await runSass(["--embed-sources", "test.scss"]);
      expect(
          sass.stdout,
          emits("When printing to stdout, --embed-sources requires "
              "--embed-source-map."));
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
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
      expect(
          sass.stdout, emitsThrough(contains("Print this usage information.")));
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
        var css = readFile(d.path("out.css"));
        map = embeddedSourceMap(css);
      });

      test("contains mappings in the generated CSS", () {
        SingleMapping sourceMap;
        sass.compileString("a {b: 1 + 2}", sourceMap: (map) => sourceMap = map);
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

      // Regression test for #457.
      test("--embed-sources works with non-ASCII characters", () async {
        await d.file("test.scss", "a {b: '▼'}").create();
        await (await runSass([
          "--embed-source-map",
          "--embed-sources",
          "test.scss",
          "out.css"
        ]))
            .shouldExit(0);
        var css = readFile(d.path("out.css"));
        map = embeddedSourceMap(css);

        expect(map, containsPair("sources", ["test.scss"]));
        expect(map, containsPair("sourcesContent", ["a {b: '▼'}"]));
      });
    });

    group("with the target in a different directory", () {
      setUp(() async {
        ensureDir(d.path("dir"));
        await (await runSass(
                ["--embed-source-map", "test.scss", "dir/out.css"]))
            .shouldExit(0);
        var css = readFile(d.path("dir/out.css"));
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
}

/// Reads the file at [path] within [d.sandbox] and JSON-decodes it.
Map<String, Object> _readJson(String path) =>
    jsonDecode(readFile(d.path(path))) as Map<String, Object>;
