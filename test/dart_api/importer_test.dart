// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'from_import_importer.dart';
import 'test_importer.dart';
import '../utils.dart';

void main() {
  test("uses an importer to resolve a @use", () {
    var css = compileString(
      '@use "orange";',
      importers: [
        TestImporter((url) => Uri.parse("u:$url"), (url) {
          var color = url.path;
          return ImporterResult('.$color {color: $color}', indented: false);
        }),
      ],
    );

    expect(css, equals(".orange {\n  color: orange;\n}"));
  });

  test("passes the canonicalized URL to the importer", () {
    var css = compileString(
      '@use "orange";',
      importers: [
        TestImporter((url) => Uri.parse('u:blue'), (url) {
          var color = url.path;
          return ImporterResult('.$color {color: $color}', indented: false);
        }),
      ],
    );

    expect(css, equals(".blue {\n  color: blue;\n}"));
  });

  test("only invokes the importer once for a given canonicalization", () {
    var css = compileString(
      """
        @import "orange";
        @import "orange";
      """,
      importers: [
        TestImporter(
          (url) => Uri.parse('u:blue'),
          expectAsync1((url) {
            var color = url.path;
            return ImporterResult('.$color {color: $color}', indented: false);
          }, count: 1),
        ),
      ],
    );

    expect(
      css,
      equalsIgnoringWhitespace("""
        .blue {
          color: blue;
        }

        .blue {
          color: blue;
        }
      """),
    );
  });

  test("resolves URLs relative to the pre-canonicalized URL", () {
    var times = 0;
    var css = compileString(
      '@use "foo:bar/baz";',
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
              indented: false,
            );
          }, count: 2),
        ),
      ],
      logger: Logger.quiet,
    );

    expect(
      css,
      equalsIgnoringWhitespace('''
      .first { url: "first"; }
      .second { url: "second"; }
    '''),
    );
  });

  group("the imported URL", () {
    // Regression test for #1137.
    test("isn't changed if it's root-relative", () {
      compileString(
        '@use "/orange";',
        importers: [
          TestImporter(
            expectAsync1((url) {
              expect(url, equals(Uri.parse("/orange")));
              return Uri.parse("u:$url");
            }),
            (url) => ImporterResult('', syntax: Syntax.scss),
          ),
        ],
      );
    });

    test("is converted to a file: URL if it's an absolute Windows path", () {
      compileString(
        '@import "C:/orange";',
        importers: [
          TestImporter(
            expectAsync1((url) {
              expect(url, equals(Uri.parse("file:///C:/orange")));
              return Uri.parse("u:$url");
            }),
            (url) => ImporterResult('', syntax: Syntax.scss),
          ),
        ],
      );
    });
  });

  group("the containing URL", () {
    test("is null for a potentially canonical scheme", () {
      late TestImporter importer;
      compileString(
        '@use "u:orange";',
        importers: [
          importer = TestImporter(
            expectAsync1((url) {
              expect(importer.publicContainingUrl, isNull);
              return url;
            }),
            (_) => ImporterResult('', indented: false),
          ),
        ],
        url: 'x:original.scss',
      );
    });

    test("throws an error outside canonicalize", () {
      late TestImporter importer;
      compileString(
        '@use "orange";',
        importers: [
          importer = TestImporter(
            (url) => Uri.parse("u:$url"),
            expectAsync1((url) {
              expect(() => importer.publicContainingUrl, throwsStateError);
              return ImporterResult('', indented: false);
            }),
          ),
        ],
      );
    });

    group("for a non-canonical scheme", () {
      test("is set to the original URL", () {
        late TestImporter importer;
        compileString(
          '@use "u:orange";',
          importers: [
            importer = TestImporter(
              expectAsync1((url) {
                expect(
                  importer.publicContainingUrl,
                  equals(Uri.parse('x:original.scss')),
                );
                return url.replace(scheme: 'x');
              }),
              (_) => ImporterResult('', indented: false),
              nonCanonicalSchemes: {'u'},
            ),
          ],
          url: 'x:original.scss',
        );
      });

      test("is null if the original URL is null", () {
        late TestImporter importer;
        compileString(
          '@use "u:orange";',
          importers: [
            importer = TestImporter(
              expectAsync1((url) {
                expect(importer.publicContainingUrl, isNull);
                return url.replace(scheme: 'x');
              }),
              (_) => ImporterResult('', indented: false),
              nonCanonicalSchemes: {'u'},
            ),
          ],
        );
      });
    });

    group("for a schemeless load", () {
      test("is set to the original URL", () {
        late TestImporter importer;
        compileString(
          '@use "orange";',
          importers: [
            importer = TestImporter(
              expectAsync1((url) {
                expect(
                  importer.publicContainingUrl,
                  equals(Uri.parse('x:original.scss')),
                );
                return Uri.parse("u:$url");
              }),
              (_) => ImporterResult('', indented: false),
            ),
          ],
          url: 'x:original.scss',
        );
      });

      test("is null if the original URL is null", () {
        late TestImporter importer;
        compileString(
          '@use "orange";',
          importers: [
            importer = TestImporter(
              expectAsync1((url) {
                expect(importer.publicContainingUrl, isNull);
                return Uri.parse("u:$url");
              }),
              (_) => ImporterResult('', indented: false),
            ),
          ],
        );
      });
    });
  });

  test(
      "throws an error if the importer returns a canonical URL with a "
      "non-canonical scheme", () {
    expect(
      () => compileString(
        '@use "orange";',
        importers: [
          TestImporter(
            expectAsync1((url) => Uri.parse("u:$url")),
            (_) => ImporterResult('', indented: false),
            nonCanonicalSchemes: {'u'},
          ),
        ],
      ),
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<SassException>());
          expect(
            error.toString(),
            contains("uses a scheme declared as non-canonical"),
          );
          return true;
        }),
      ),
    );
  });

  test("uses an importer's source map URL", () {
    var result = compileStringToResult(
      '@use "orange";',
      importers: [
        TestImporter((url) => Uri.parse("u:$url"), (url) {
          var color = url.path;
          return ImporterResult(
            '.$color {color: $color}',
            sourceMapUrl: Uri.parse("u:blue"),
            indented: false,
          );
        }),
      ],
      sourceMap: true,
    );

    expect(result.sourceMap!.urls, contains("u:blue"));
  });

  test("uses a data: source map URL if the importer doesn't provide one", () {
    var result = compileStringToResult(
      '@use "orange";',
      importers: [
        TestImporter((url) => Uri.parse("u:$url"), (url) {
          var color = url.path;
          return ImporterResult('.$color {color: $color}', indented: false);
        }),
      ],
      sourceMap: true,
    );

    expect(
      result.sourceMap!.urls,
      contains(
        Uri.dataFromString(
          ".orange {color: orange}",
          encoding: utf8,
        ).toString(),
      ),
    );
  });

  test("wraps an error in canonicalize()", () {
    expect(
      () {
        compileString(
          '@use "orange";',
          importers: [
            TestImporter((url) {
              throw "this import is bad actually";
            }, expectNever1),
          ],
        );
      },
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<SassException>());
          expect(
            error.toString(),
            startsWith("Error: this import is bad actually"),
          );
          return true;
        }),
      ),
    );
  });

  test("wraps an error in load()", () {
    expect(
      () {
        compileString(
          '@use "orange";',
          importers: [
            TestImporter((url) => Uri.parse("u:$url"), (url) {
              throw "this import is bad actually";
            }),
          ],
        );
      },
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<SassException>());
          expect(
            error.toString(),
            startsWith("Error: this import is bad actually"),
          );
          return true;
        }),
      ),
    );
  });

  test("prefers .message to .toString() for an importer error", () {
    expect(
      () {
        compileString(
          '@use "orange";',
          importers: [
            TestImporter((url) => Uri.parse("u:$url"), (url) {
              throw FormatException("bad format somehow");
            }),
          ],
        );
      },
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<SassException>());
          // FormatException.toString() starts with "FormatException:", but
          // the error message should not.
          expect(error.toString(), startsWith("Error: bad format somehow"));
          return true;
        }),
      ),
    );
  });

  test("avoids importer when only load() returns null", () {
    expect(
      () {
        compileString(
          '@use "orange";',
          importers: [
            TestImporter((url) => Uri.parse("u:$url"), (url) => null),
          ],
        );
      },
      throwsA(
        predicate((error) {
          expect(error, const TypeMatcher<SassException>());
          expect(
            error.toString(),
            startsWith("Error: Can't find stylesheet to import"),
          );
          return true;
        }),
      ),
    );
  });

  group("compileString()'s importer option", () {
    test("loads relative imports from the entrypoint", () {
      var css = compileString(
        '@use "orange";',
        importer: TestImporter((url) => Uri.parse("u:$url"), (url) {
          var color = url.path;
          return ImporterResult('.$color {color: $color}', indented: false);
        }),
      );

      expect(css, equals(".orange {\n  color: orange;\n}"));
    });

    test("loads imports relative to the entrypoint's URL", () {
      var css = compileString(
        '@use "baz/qux";',
        importer: TestImporter((url) => url.resolve("bang"), (url) {
          return ImporterResult('a {result: "${url.path}"}', indented: false);
        }),
        url: Uri.parse("u:foo/bar"),
      );

      expect(css, equals('a {\n  result: "foo/baz/bang";\n}'));
    });

    test("doesn't load absolute imports", () {
      var css = compileString(
        '@use "u:orange";',
        importer: TestImporter(
          (_) => throw "Should not be called",
          (_) => throw "Should not be called",
        ),
        importers: [
          TestImporter((url) => url, (url) {
            var color = url.path;
            return ImporterResult('.$color {color: $color}', indented: false);
          }),
        ],
      );

      expect(css, equals(".orange {\n  color: orange;\n}"));
    });

    test("doesn't load from other importers", () {
      var css = compileString(
        '@use "u:midstream";',
        importer: TestImporter(
          (_) => throw "Should not be called",
          (_) => throw "Should not be called",
        ),
        importers: [
          TestImporter((url) => url, (url) {
            if (url.path == "midstream") {
              return ImporterResult("@use 'orange';", indented: false);
            } else {
              var color = url.path;
              return ImporterResult('.$color {color: $color}', indented: false);
            }
          }),
        ],
      );

      expect(css, equals(".orange {\n  color: orange;\n}"));
    });
  });

  group("currentLoadFromImport is", () {
    test("true from an @import", () {
      compileString('@import "foo"', importers: [FromImportImporter(true)]);
    });

    test("false from a @use", () {
      compileString('@use "foo"', importers: [FromImportImporter(false)]);
    });

    test("false from a @forward", () {
      compileString('@forward "foo"', importers: [FromImportImporter(false)]);
    });

    test("false from meta.load-css", () {
      compileString(
        '@use "sass:meta"; @include meta.load-css("")',
        importers: [FromImportImporter(false)],
      );
    });
  });
}
