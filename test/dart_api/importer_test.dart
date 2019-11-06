// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:convert';

import 'package:source_maps/source_maps.dart';
import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

import 'test_importer.dart';

void main() {
  test("uses an importer to resolve an @import", () {
    var css = compileString('@import "orange";', importers: [
      TestImporter((url) => Uri.parse("u:$url"), (url) {
        var color = url.path;
        return ImporterResult('.$color {color: $color}', indented: false);
      })
    ]);

    expect(css, equals(".orange {\n  color: orange;\n}"));
  });

  test("passes the canonicalized URL to the importer", () {
    var css = compileString('@import "orange";', importers: [
      TestImporter((url) => Uri.parse('u:blue'), (url) {
        var color = url.path;
        return ImporterResult('.$color {color: $color}', indented: false);
      })
    ]);

    expect(css, equals(".blue {\n  color: blue;\n}"));
  });

  test("only invokes the importer once for a given canonicalization", () {
    var css = compileString("""
      @import "orange";
      @import "orange";
    """, importers: [
      TestImporter(
          (url) => Uri.parse('u:blue'),
          expectAsync1((url) {
            var color = url.path;
            return ImporterResult('.$color {color: $color}', indented: false);
          }, count: 1))
    ]);

    expect(css, equals("""
.blue {
  color: blue;
}

.blue {
  color: blue;
}"""));
  });

  test("resolves URLs relative to the pre-canonicalized URL", () {
    var times = 0;
    var css = compileString('@import "foo:bar/baz";',
        importers: [
          TestImporter(
              expectAsync1((url) {
                times++;
                if (times == 1) return Uri(path: 'first');

                expect(url, equals(Uri.parse('foo:bar/bang')));
                return Uri(path: 'second');
              }, count: 2),
              expectAsync1((url) {
                return ImporterResult(
                    times == 1
                        ? '''
                        .first {url: "$url"}
                        @import "bang";
                      '''
                        : '.second {url: "$url"}',
                    indented: false);
              }, count: 2))
        ],
        logger: Logger.quiet);

    expect(css, equalsIgnoringWhitespace('''
      .first { url: "first"; }
      .second { url: "second"; }
    '''));
  });

  test("uses an importer's source map URL", () {
    SingleMapping map;
    compileString('@import "orange";',
        importers: [
          TestImporter((url) => Uri.parse("u:$url"), (url) {
            var color = url.path;
            return ImporterResult('.$color {color: $color}',
                sourceMapUrl: Uri.parse("u:blue"), indented: false);
          })
        ],
        sourceMap: (map_) => map = map_);

    expect(map.urls, contains("u:blue"));
  });

  test("uses a data: source map URL if the importer doesn't provide one", () {
    SingleMapping map;
    compileString('@import "orange";',
        importers: [
          TestImporter((url) => Uri.parse("u:$url"), (url) {
            var color = url.path;
            return ImporterResult('.$color {color: $color}', indented: false);
          })
        ],
        sourceMap: (map_) => map = map_);

    expect(
        map.urls,
        contains(Uri.dataFromString(".orange {color: orange}", encoding: utf8)
            .toString()));
  });

  test("wraps an error in canonicalize()", () {
    expect(() {
      compileString('@import "orange";', importers: [
        TestImporter((url) {
          throw "this import is bad actually";
        }, expectAsync1((_) => null, count: 0))
      ]);
    }, throwsA(predicate((error) {
      expect(error, const TypeMatcher<SassException>());
      expect(
          error.toString(), startsWith("Error: this import is bad actually"));
      return true;
    })));
  });

  test("wraps an error in load()", () {
    expect(() {
      compileString('@import "orange";', importers: [
        TestImporter((url) => Uri.parse("u:$url"), (url) {
          throw "this import is bad actually";
        })
      ]);
    }, throwsA(predicate((error) {
      expect(error, const TypeMatcher<SassException>());
      expect(
          error.toString(), startsWith("Error: this import is bad actually"));
      return true;
    })));
  });

  test("prefers .message to .toString() for an importer error", () {
    expect(() {
      compileString('@import "orange";', importers: [
        TestImporter((url) => Uri.parse("u:$url"), (url) {
          throw FormatException("bad format somehow");
        })
      ]);
    }, throwsA(predicate((error) {
      expect(error, const TypeMatcher<SassException>());
      // FormatException.toString() starts with "FormatException:", but
      // the error message should not.
      expect(error.toString(), startsWith("Error: bad format somehow"));
      return true;
    })));
  });
}
