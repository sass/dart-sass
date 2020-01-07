// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:convert';

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:test/test.dart';

import 'package:sass/sass.dart' as dart_sass;

import '../ensure_npm_package.dart';
import '../hybrid.dart';
import '../utils.dart';
import 'api.dart';
import 'utils.dart';

/// A [Codec] that encodes and decodes UTF-8-encoded JSON.
var _jsonUtf8 = json.fuse(utf8);

void main() {
  setUpAll(ensureNpmPackage);
  useSandbox();

  group("a basic invocation", () {
    String css;
    Map<String, Object> map;
    setUp(() {
      var result = sass.renderSync(
          RenderOptions(data: "a {b: c}", sourceMap: true, outFile: "out.css"));
      css = utf8.decode(result.css);
      map = _jsonUtf8.decode(result.map) as Map<String, Object>;
    });

    test("includes correct mappings", () {
      SingleMapping expectedMap;
      dart_sass.compileString("a {b: c}",
          sourceMap: (map) => expectedMap = map);
      expectedMap.targetUrl = "out.css";

      expect(map, containsPair("mappings", expectedMap.toJson()["mappings"]));
    });

    test("includes the name of the output file", () {
      expect(map, containsPair("file", "out.css"));
    });

    test("includes stdin as a source", () {
      expect(map, containsPair("sources", ["stdin"]));
    });

    test("includes a source map comment", () {
      expect(css, endsWith("\n\n/*# sourceMappingURL=out.css.map */"));
    });
  });

  group("the sources list", () {
    test("contains a relative path to an input file", () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, 'a {b: c}');

      var map = _renderSourceMap(RenderOptions(
          file: path, sourceMap: true, outFile: p.join(sandbox, 'out.css')));
      expect(map, containsPair("sources", ["test.scss"]));
    });

    test("makes the path relative to outFile", () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, 'a {b: c}');

      var map = _renderSourceMap(RenderOptions(
          file: path,
          sourceMap: true,
          outFile: p.join(p.dirname(sandbox), 'dir/out.css')));
      expect(
          map,
          containsPair("sources", [
            p.toUri(p.join("..", p.basename(sandbox), "test.scss")).toString()
          ]));
    });

    test("contains an imported file's path", () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, '''
        @import "other";
        a {b: c}
      ''');

      await writeTextFile(p.join(sandbox, 'other.scss'), 'x {y: z}');

      var map = _renderSourceMap(RenderOptions(
          file: path, sourceMap: true, outFile: p.join(sandbox, 'out.css')));
      expect(map, containsPair("sources", ["other.scss", "test.scss"]));
    });

    test("contains the resolved path of a file imported via includePaths",
        () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, '''
        @import "other";
        a {b: c}
      ''');

      await createDirectory(p.join(sandbox, 'subdir'));
      await writeTextFile(p.join(sandbox, 'subdir/other.scss'), 'x {y: z}');

      var map = _renderSourceMap(RenderOptions(
          file: path,
          sourceMap: true,
          includePaths: [p.join(sandbox, 'subdir')],
          outFile: p.join(sandbox, 'out.css')));
      expect(map, containsPair("sources", ["subdir/other.scss", "test.scss"]));
    });

    test("contains a URL handled by an importer", () {
      var map = _renderSourceMap(RenderOptions(
          data: '''
        @import "other";
        a {b: c}
      ''',
          importer: allowInterop(
              (void _, void __) => NodeImporterResult(contents: 'x {y: z}')),
          sourceMap: true,
          outFile: 'out.css'));
      expect(map, containsPair("sources", ["other", "stdin"]));
    });
  });

  group("doesn't emit the source map", () {
    test("without sourceMap", () {
      var result =
          sass.renderSync(RenderOptions(data: "a {b: c}", outFile: "out.css"));
      expect(result.map, isNull);
      expect(utf8.decode(result.css), isNot(contains("/*#")));
    });

    test("with sourceMap: false", () {
      var result = sass.renderSync(RenderOptions(
          data: "a {b: c}", sourceMap: false, outFile: "out.css"));
      expect(result.map, isNull);
      expect(utf8.decode(result.css), isNot(contains("/*#")));
    });

    test("without outFile", () {
      var result =
          sass.renderSync(RenderOptions(data: "a {b: c}", sourceMap: true));
      expect(result.map, isNull);
      expect(utf8.decode(result.css), isNot(contains("/*#")));
    });
  });

  group("with a string sourceMap and no outFile", () {
    test("emits a source map", () {
      var result = sass.renderSync(
          RenderOptions(data: "a {b: c}", sourceMap: "out.css.map"));
      var map = _jsonUtf8.decode(result.map) as Map<String, Object>;
      expect(map, containsPair("sources", ["stdin"]));
    });

    test("derives the target URL from the input file", () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, 'a {b: c}');

      var result = sass.renderSync(RenderOptions(
          file: p.join(sandbox, "test.scss"), sourceMap: "out.css.map"));
      var map = _jsonUtf8.decode(result.map) as Map<String, Object>;
      expect(
          map,
          containsPair(
              "file", p.toUri(p.join(sandbox, "test.css")).toString()));
    });

    test("derives the target URL from the input file without an extension",
        () async {
      var path = p.join(sandbox, 'test');
      await writeTextFile(path, 'a {b: c}');

      var result = sass.renderSync(RenderOptions(
          file: p.join(sandbox, "test"), sourceMap: "out.css.map"));
      var map = _jsonUtf8.decode(result.map) as Map<String, Object>;
      expect(
          map,
          containsPair(
              "file", p.toUri(p.join(sandbox, "test.css")).toString()));
    });

    test("derives the target URL from stdin", () {
      var result = sass.renderSync(
          RenderOptions(data: "a {b: c}", sourceMap: "out.css.map"));
      var map = _jsonUtf8.decode(result.map) as Map<String, Object>;
      expect(map, containsPair("file", "stdin.css"));
    });

    // Regression test for sass/dart-sass#922
    test("contains a URL handled by an importer when sourceMap is absolute",
        () {
      var map = _renderSourceMap(RenderOptions(
          data: '''
        @import "other";
        a {b: c}
      ''',
          importer: allowInterop(
              (void _, void __) => NodeImporterResult(contents: 'x {y: z}')),
          sourceMap: p.absolute("out.css.map"),
          outFile: 'out.css'));
      expect(map, containsPair("sources", ["other", "stdin"]));
    });
  });

  test("with omitSourceMapUrl, doesn't include a source map comment", () {
    var result = sass.renderSync(RenderOptions(
        data: "a {b: c}",
        sourceMap: true,
        outFile: "out.css",
        omitSourceMapUrl: true));
    expect(result.map, isNotNull);
    expect(utf8.decode(result.css), isNot(contains("/*#")));
  });

  group("with a string sourceMap", () {
    test("uses it in the source map comment", () {
      var result = sass.renderSync(RenderOptions(
          data: "a {b: c}", sourceMap: "map", outFile: "out.css"));
      expect(result.map, isNotNull);
      expect(
          utf8.decode(result.css), endsWith("\n\n/*# sourceMappingURL=map */"));
    });

    test("makes the source map comment relative to the outfile", () {
      var result = sass.renderSync(RenderOptions(
          data: "a {b: c}", sourceMap: "map", outFile: "dir/out.css"));
      expect(result.map, isNotNull);
      expect(utf8.decode(result.css),
          endsWith("\n\n/*# sourceMappingURL=../map */"));
    });

    test("makes the file field relative to the source map location", () {
      var map = _renderSourceMap(RenderOptions(
          data: "a {b: c}", sourceMap: "dir/map", outFile: "out.css"));
      expect(map, containsPair("file", "../out.css"));
    });

    test("makes the source map comment relative even if the path is absolute",
        () {
      var result = sass.renderSync(RenderOptions(
          data: "a {b: c}", sourceMap: p.absolute("map"), outFile: "out.css"));
      expect(result.map, isNotNull);
      expect(
          utf8.decode(result.css), endsWith("\n\n/*# sourceMappingURL=map */"));
    });

    test("makes the sources list relative to the map location", () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, 'a {b: c}');

      var map = _renderSourceMap(RenderOptions(
          file: path, sourceMap: p.join(sandbox, 'map'), outFile: 'out.css'));
      expect(map, containsPair("sources", ["test.scss"]));
    });
  });

  group("with sourceMapContents", () {
    test("includes the source contents in the source map", () {
      var map = _renderSourceMap(RenderOptions(
          data: "a {b: c}",
          sourceMap: true,
          outFile: "out.css",
          sourceMapContents: true));
      expect(map, containsPair("sourcesContent", ["a {b: c}"]));
    });

    test("includes an imported file's contents in the source map", () async {
      var path = p.join(sandbox, 'test.scss');
      var scss = '''
        @import "other";
        a {b: c}
      ''';
      await writeTextFile(path, scss);

      await writeTextFile(p.join(sandbox, 'other.scss'), 'x {y: z}');

      var map = _renderSourceMap(RenderOptions(
          file: path,
          sourceMap: true,
          outFile: 'out.css',
          sourceMapContents: true));
      expect(map, containsPair("sourcesContent", ["x {y: z}", scss]));
    });
  });

  test("with sourceMapEmbed includes the source map in the CSS", () {
    var result = sass.renderSync(RenderOptions(
        data: "a {b: c}",
        sourceMap: true,
        outFile: "out.css",
        sourceMapEmbed: true));

    var map = embeddedSourceMap(utf8.decode(result.css));
    expect(map, equals(_jsonUtf8.decode(result.map)));
  });

  group("with sourceMapRoot", () {
    test("includes the root as-is in the map", () {
      var map = _renderSourceMap(RenderOptions(
          data: "a {b: c}",
          sourceMap: true,
          outFile: 'out.css',
          sourceMapRoot: 'some random string'));
      expect(map, containsPair("sourceRoot", "some random string"));
    });

    test("doesn't modify the source URLs", () async {
      var path = p.join(sandbox, 'test.scss');
      await writeTextFile(path, 'a {b: c}');

      var root = p.toUri(p.dirname(sandbox)).toString();
      var map = _renderSourceMap(RenderOptions(
          file: path,
          sourceMap: true,
          outFile: p.join(sandbox, 'out.css'),
          sourceMapRoot: root));
      expect(map, containsPair("sourceRoot", root));
      expect(map, containsPair("sources", ["test.scss"]));
    });
  });
}

/// Renders [options] and returns the decoded source map.
Map<String, Object> _renderSourceMap(RenderOptions options) =>
    _jsonUtf8.decode(sass.renderSync(options).map) as Map<String, Object>;
