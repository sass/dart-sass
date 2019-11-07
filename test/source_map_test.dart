// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/utils.dart';

import 'dart_api/test_importer.dart';

void main() {
  group("maps source to target for", () {
    group("a style rule", () {
      test("that's basic", () {
        _expectSourceMap("""
          {{1}}foo
            {{2}}bar: baz
        """, """
          {{1}}foo {
            {{2}}bar: baz;
          }
        """, """
          {{1}}foo {
            {{2}}bar: baz;
          }
        """);
      });

      test("with a mutliline selector", () {
        _expectSourceMap("""
          {{1}}foo,
          bar
            {{2}}bar: baz
        """, """
          {{1}}foo,
          bar {
            {{2}}bar: baz;
          }
        """, """
          {{1}}foo,
          {{1}}bar {
            {{2}}bar: baz;
          }
        """);
      });

      test("with a property on a different line", () {
        _expectScssSourceMap("""
          {{1}}foo {
            {{2}}bar:
                {{3}}baz;
          }
        """, """
          {{1}}foo {
            {{2}}bar: {{3}}baz;
          }
        """);
      });

      test("with a multiline property", () {
        _expectScssSourceMap("""
          {{1}}foo {
            {{2}}bar: baz
                bang;
          }
        """, """
          {{1}}foo {
            {{2}}bar: baz bang;
          }
        """);
      });

      test("that's nested", () {
        _expectSourceMap("""
          foo
            {{1}}bar
              {{2}}baz: bang
        """, """
          foo {
            {{1}}bar {
              {{2}}baz: bang;
            }
          }
        """, """
          {{1}}foo bar {
            {{2}}baz: bang;
          }
        """);
      });

      test("with a nested rule and declaration", () {
        _expectSourceMap("""
          {{1}}foo
            {{2}}a: b

            {{3}}bar
              {{4}}x: y
        """, """
          {{1}}foo {
            {{2}}a: b;

            {{3}}bar {
              {{4}}x: y;
            }
          }
        """, """
          {{1}}foo {
            {{2}}a: b;
          }
          {{3}}foo bar {
            {{4}}x: y;
          }
        """);
      });

      test("with a nested declaration", () {
        _expectSourceMap("""
          {{1}}foo
            {{2}}a: b
              {{3}}c: d
        """, """
          {{1}}foo {
            {{2}}a: b {
              {{3}}c: d;
            }
          }
        """, """
          {{1}}foo {
            {{2}}a: b;
            {{3}}a-c: d;
          }
        """);
      });
    });

    group("an unknown at-rule", () {
      test("without children", () {
        _expectSourceMap("""
          {{1}}@foo (fblthp)
        """, """
          {{1}}@foo (fblthp);
        """, """
          {{1}}@foo (fblthp);
        """);
      });

      group("that contains", () {
        test("declarations", () {
          _expectSourceMap("""
            {{1}}@foo (fblthp)
              {{2}}bar: baz
          """, """
            {{1}}@foo (fblthp) {
              {{2}}bar: baz;
            }
          """, """
            {{1}}@foo (fblthp) {
              {{2}}bar: baz;
            }
          """);
        });

        test("style rules", () {
          _expectSourceMap("""
            {{1}}@foo (fblthp)
              {{2}}bar
                {{3}}baz: bang
          """, """
            {{1}}@foo (fblthp) {
              {{2}}bar {
                {{3}}baz: bang;
              }
            }
          """, """
            {{1}}@foo (fblthp) {
              {{2}}bar {
                {{3}}baz: bang;
              }
            }
          """);
        });

        test("at-rules", () {
          _expectSourceMap("""
            {{1}}@foo (fblthp)
              {{2}}@bar baz
          """, """
            {{1}}@foo (fblthp) {
              {{2}}@bar baz;
            }
          """, """
            {{1}}@foo (fblthp) {
              {{2}}@bar baz;
            }
          """);
        });
      });
    });

    group("a comment", () {
      test("that covers a single line", () {
        _expectSourceMap("""
          {{1}}/* foo bar
          {{2}}/* baz bang
        """, """
          {{1}}/* foo bar */
          {{2}}/* baz bang */
        """, """
          {{1}}/* foo bar */
          {{2}}/* baz bang */
        """);
      });

      test("that covers multiple lines", () {
        _expectSourceMap("""
          {{1}}/* foo bar
             baz bang
        """, """
          {{1}}/* foo bar
           * baz bang */
        """, """
          {{1}}/* foo bar
          {{1}} * baz bang */
        """);
      });
    });

    group("@import", () {
      test("with a single URL", () {
        _expectSourceMap("""
          @import {{1}}url(foo)
        """, """
          @import {{1}}url(foo);
        """, """
          {{1}}@import url(foo);
        """);
      });

      test("with multiple URLs", () {
        _expectSourceMap("""
          @import {{1}}url(foo), {{2}}"bar.css"
        """, """
          @import {{1}}url(foo),
            {{2}}"bar.css";
        """, """
          {{1}}@import url(foo);
          {{2}}@import "bar.css";
        """);
      });
    });

    test("@keyframes", () {
      _expectSourceMap("""
        {{1}}@keyframes name
          {{2}}from
            {{3}}top: 0px

          {{4}}10%
            {{5}}top: 10px
      """, """
        {{1}}@keyframes name {
          {{2}}from {
            {{3}}top: 0px;
          }

          {{4}}10% {
            {{5}}top: 10px;
          }
        }
      """, """
        {{1}}@keyframes name {
          {{2}}from {
            {{3}}top: 0px;
          }
          {{4}}10% {
            {{5}}top: 10px;
          }
        }
      """);
    });

    group("@media", () {
      test("at the root", () {
        _expectSourceMap("""
          {{1}}@media screen
            {{2}}foo
              {{3}}bar: baz
        """, """
          {{1}}@media screen {
            {{2}}foo {
              {{3}}bar: baz;
            }
          }
        """, """
          {{1}}@media screen {
            {{2}}foo {
              {{3}}bar: baz;
            }
          }
        """);
      });

      test("within a style rule", () {
        _expectSourceMap("""
          {{1}}foo
            {{2}}@media screen
              {{3}}bar: baz
        """, """
          {{1}}foo {
            {{2}}@media screen {
              {{3}}bar: baz;
            }
          }
        """, """
          {{2}}@media screen {
            {{1}}foo {
              {{3}}bar: baz;
            }
          }
        """);
      });
    });

    group("@supports", () {
      test("at the root", () {
        _expectSourceMap("""
          {{1}}@supports (display: grid)
            {{2}}foo
              {{3}}bar: baz
        """, """
          {{1}}@supports (display: grid) {
            {{2}}foo {
              {{3}}bar: baz;
            }
          }
        """, """
          {{1}}@supports (display: grid) {
            {{2}}foo {
              {{3}}bar: baz;
            }
          }
        """);
      });

      test("within a style rule", () {
        _expectSourceMap("""
          {{1}}foo
            {{2}}@supports (display: grid)
              {{3}}bar: baz
        """, """
          {{1}}foo {
            {{2}}@supports (display: grid) {
              {{3}}bar: baz;
            }
          }
        """, """
          {{2}}@supports (display: grid) {
            {{1}}foo {
              {{3}}bar: baz;
            }
          }
        """);
      });
    });

    group("a value from a variable defined", () {
      group("in", () {
        test("a variable declaration", () {
          _expectScssSourceMap(r"""
            $var: {{1}}value;

            {{2}}a {
              {{3}}b: $var;
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}value;
            }
          """);
        });

        test("an @each rule", () {
          _expectScssSourceMap(r"""
            @each $var in {{1}}1 2 {
              {{2}}a {
                {{3}}b: $var;
              }
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}1;
            }

            {{2}}a {
              {{3}}b: {{1}}2;
            }
          """);
        });

        test("a @for rule", () {
          _expectScssSourceMap(r"""
            @for $var from {{1}}1 through 2 {
              {{2}}a {
                {{3}}b: $var;
              }
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}1;
            }

            {{2}}a {
              {{3}}b: {{1}}2;
            }
          """);
        });

        group("a mixin argument that is", () {
          test("the default value", () {
            _expectScssSourceMap(r"""
              @mixin foo($var: {{1}}1) {
                {{2}}b: $var;
              }

              {{3}}a {
                @include foo();
              }
            """, """
              {{3}}a {
                {{2}}b: {{1}}1;
              }
            """);
          });

          test("passed by position", () {
            _expectScssSourceMap(r"""
              @mixin foo($var) {
                {{1}}b: $var;
              }

              {{2}}a {
                @include foo({{3}}1);
              }
            """, """
              {{2}}a {
                {{1}}b: {{3}}1;
              }
            """);
          });

          test("passed by name", () {
            _expectScssSourceMap(r"""
              @mixin foo($var) {
                {{1}}b: $var;
              }

              {{2}}a {
                @include foo($var: {{3}}1);
              }
            """, """
              {{2}}a {
                {{1}}b: {{3}}1;
              }
            """);
          });

          test("passed by arglist", () {
            _expectScssSourceMap(r"""
              @mixin foo($var) {
                {{1}}b: $var;
              }

              {{2}}a {
                @include foo({{3}}(1,)...);
              }
            """, """
              {{2}}a {
                {{1}}b: {{3}}1;
              }
            """);
          });
        });
      });

      group("in a variable which is referenced by", () {
        test("a variable rename", () {
          _expectScssSourceMap(r"""
            $var1: {{1}}value;
            $var2: $var1;

            {{2}}a {
              {{3}}b: $var2;
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}value;
            }
          """);
        });

        test("an @each rule from a variable", () {
          _expectScssSourceMap(r"""
            $list: {{1}}1 2;

            @each $var in $list {
              {{2}}a {
                {{3}}b: $var;
              }
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}1;
            }

            {{2}}a {
              {{3}}b: {{1}}2;
            }
          """);
        });

        test("a @for rule from a variable", () {
          _expectScssSourceMap(r"""
            $start: {{1}}1;
            $end: 2;

            @for $var from $start through $end {
              {{2}}a {
                {{3}}b: $var;
              }
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}1;
            }

            {{2}}a {
              {{3}}b: {{1}}2;
            }
          """);
        });

        test("a @use rule with a with clause", () {
          _expectScssSourceMap(r"""
            $var1: {{1}}new value;
            @use 'other' with ($var2: $var1);

            {{2}}a {
              {{3}}b: other.$var2;
            }
          """, """
            {{2}}a {
              {{3}}b: {{1}}new value;
            }
          """,
              importer: TestImporter(
                  (url) => Uri.parse("u:$url"),
                  (_) => ImporterResult(r"$var2: default value !default;",
                      syntax: Syntax.scss)));
        });

        group("a mixin argument that is", () {
          test("the default value", () {
            _expectScssSourceMap(r"""
              $original: {{1}}1;

              @mixin foo($var: $original) {
                {{2}}b: $var;
              }

              {{3}}a {
                @include foo();
              }
            """, """
              {{3}}a {
                {{2}}b: {{1}}1;
              }
            """);
          });

          test("passed by position", () {
            _expectScssSourceMap(r"""
              $original: {{1}}1;

              @mixin foo($var) {
                {{2}}b: $var;
              }

              {{3}}a {
                @include foo($original);
              }
            """, """
              {{3}}a {
                {{2}}b: {{1}}1;
              }
            """);
          });

          test("passed by name", () {
            _expectScssSourceMap(r"""
              $original: {{1}}1;

              @mixin foo($var) {
                {{2}}b: $var;
              }

              {{3}}a {
                @include foo($var: $original);
              }
            """, """
              {{3}}a {
                {{2}}b: {{1}}1;
              }
            """);
          });

          test("passed by arglist", () {
            _expectScssSourceMap(r"""
              $original: {{1}}1;

              @mixin foo($var) {
                {{2}}b: $var;
              }

              {{3}}a {
                @include foo($original...);
              }
            """, """
              {{3}}a {
                {{2}}b: {{1}}1;
              }
            """);
          });
        });
      });
    });

    group("a stylesheet with Unicode characters", () {
      test("in expanded mode", () {
        _expectSourceMap("""
        {{1}}föö
          {{2}}bär: bäz
      """, """
        {{1}}föö {
          {{2}}bär: bäz;
        }
      """, """
        @charset "UTF-8";
        {{1}}föö {
          {{2}}bär: bäz;
        }
      """);
      });

      test("in compressed mode", () {
        _expectSourceMap("""
        {{1}}föö
          {{2}}bär: bäz
      """, """
        {{1}}föö {
          {{2}}bär: bäz;
        }
      """, "\uFEFF{{1}}föö{{{2}}bär:bäz}", style: OutputStyle.compressed);
      });
    });
  });

  test("doesn't use the source map location for variable errors", () {
    // When source maps are enabled (by passing a callback to sourceMap), Sass
    // tracks the original location where each variable was declared so that
    // browsers can link to variable declarations rather than just usages.
    // However, we want to refer to the usages when reporting errors because
    // they have more context.
    expect(() {
      compileString(r"""
        $map: (a: b);
        x {y: $map}
      """, sourceMap: (_) {});
    }, throwsA(predicate((untypedError) {
      var error = untypedError as SourceSpanException;
      expect(error.span.text, equals(r"$map"));
      return true;
    })));
  });
}

/// Asserts that [sass] and [scss] both compile to [css], and that the
/// associated source maps are generated properly.
///
/// All three strings are expected to be annotated to indicate which locations
/// in the source Sass and SCSS should map to which locations in the CSS. This
/// is done using numbers enclosed in double curly braces called "location
/// identifiers'. For example, the source text
///
///     {{1}}foo{{2}}: {{3}}1 + 1{{4}};
///
/// indicates four locations that should be mapped to the locations with the
/// same numbers in the target text:
///
///     {{1}}foo{{2}}: {{3}}2{{4}};
///
/// The [css] text may have multiple instances of the same location identifier,
/// which indicates that the same source text is mapped to multiple different
/// target locations.
///
/// This also re-indents the input strings with [_reindent].
void _expectSourceMap(String sass, String scss, String css,
    {Importer importer, OutputStyle style}) {
  _expectSassSourceMap(sass, css, importer: importer, style: style);
  _expectScssSourceMap(scss, css, importer: importer, style: style);
}

/// Like [_expectSourceMap], but with only SCSS source.
void _expectScssSourceMap(String scss, String css,
    {Importer importer, OutputStyle style}) {
  var scssTuple = _extractLocations(_reindent(scss));
  var scssText = scssTuple.item1;
  var scssLocations = _tuplesToMap(scssTuple.item2);

  var cssTuple = _extractLocations(_reindent(css));
  var cssText = cssTuple.item1;
  var cssLocations = cssTuple.item2;

  SingleMapping scssMap;
  var scssOutput = compileString(scssText,
      sourceMap: (map) => scssMap = map, importer: importer, style: style);
  expect(scssOutput, equals(cssText));
  _expectMapMatches(scssMap, scssText, cssText, scssLocations, cssLocations);
}

/// Like [_expectSourceMap], but with only indented source.
void _expectSassSourceMap(String sass, String css,
    {Importer importer, OutputStyle style}) {
  var sassTuple = _extractLocations(_reindent(sass));
  var sassText = sassTuple.item1;
  var sassLocations = _tuplesToMap(sassTuple.item2);

  var cssTuple = _extractLocations(_reindent(css));
  var cssText = cssTuple.item1;
  var cssLocations = cssTuple.item2;

  SingleMapping sassMap;
  var sassOutput = compileString(sassText,
      indented: true,
      sourceMap: (map) => sassMap = map,
      importer: importer,
      style: style);
  expect(sassOutput, equals(cssText));
  _expectMapMatches(sassMap, sassText, cssText, sassLocations, cssLocations);
}

/// Returns [string] with leading whitepsace stripped from each line so that the
/// least-indented line has zero indentation.
String _reindent(String string) {
  var lines = trimAsciiRight(string).split("\n");
  var minIndent = lines
      .where((line) => trimAscii(line).isNotEmpty)
      .map((line) => line.length - trimAsciiLeft(line).length)
      .reduce((length1, length2) => length1 < length2 ? length1 : length2);
  return lines
      .map((line) => trimAscii(line).isEmpty ? "" : line.substring(minIndent))
      .join("\n");
}

/// Parses and removes the location annotations from [text].
Tuple2<String, List<Tuple2<String, SourceLocation>>> _extractLocations(
    String text) {
  var scanner = StringScanner(text);
  var buffer = StringBuffer();
  var locations = <Tuple2<String, SourceLocation>>[];

  var offset = 0;
  var line = 0;
  var column = 0;
  while (!scanner.isDone) {
    if (scanner.matches(RegExp(r"{{[^{]"))) {
      scanner.expect("{{");
      var start = scanner.position;
      while (!scanner.scan("}}")) {
        scanner.readChar();
      }
      locations.add(Tuple2(scanner.substring(start, scanner.position - 2),
          SourceLocation(offset, line: line, column: column)));
    } else if (scanner.scanChar($lf)) {
      offset++;
      line++;
      column = 0;
      buffer.writeln();
    } else {
      buffer.writeCharCode(scanner.readChar());
      offset++;
      column++;
    }
  }

  return Tuple2(buffer.toString(), locations);
}

/// Converts a list of tuples to a map, asserting that each key appears only
/// once.
Map<K, V> _tuplesToMap<K, V>(Iterable<Tuple2<K, V>> tuples) {
  var map = <K, V>{};
  for (var tuple in tuples) {
    expect(map, isNot(contains(tuple.item1)));
    map[tuple.item1] = tuple.item2;
  }
  return map;
}

/// Asserts that the entries in [map] match the map given by [sourceLocations]
/// and [targetLocations].
void _expectMapMatches(
    SingleMapping map,
    String sourceText,
    String targetText,
    Map<String, SourceLocation> sourceLocations,
    List<Tuple2<String, SourceLocation>> targetLocations) {
  expect(sourceLocations.keys,
      equals({for (var tuple in targetLocations) tuple.item1}));

  String actualMap() =>
      "\nActual map:\n\n" + _mapToString(map, sourceText, targetText) + "\n";

  var entryIter = _entriesForMap(map).iterator;
  for (var tuple in targetLocations) {
    var name = tuple.item1;
    var expectedTarget = tuple.item2;
    var expectedSource = sourceLocations[name];

    if (!entryIter.moveNext()) {
      fail('Missing mapping "$name", expected '
              '${_mapping(expectedSource, expectedTarget)}.\n' +
          actualMap());
    }

    var entry = entryIter.current;
    if (expectedSource.line != entry.source.line ||
        expectedSource.column != entry.source.column ||
        expectedTarget.line != entry.target.line ||
        expectedTarget.column != entry.target.column) {
      fail('Mapping "$name" was ${_mapping(entry.source, entry.target)}, '
              'expected ${_mapping(expectedSource, expectedTarget)}.\n' +
          actualMap());
    }
  }

  expect(entryIter.moveNext(), isFalse,
      reason: 'Expected no more mappings.\n' + actualMap());
}

/// Converts a [map] back into [Entry]s.
Iterable<Entry> _entriesForMap(SingleMapping map) sync* {
  for (var lineEntry in map.lines) {
    for (var entry in lineEntry.entries) {
      yield Entry(
          SourceLocation(0, line: entry.sourceLine, column: entry.sourceColumn),
          SourceLocation(0, line: lineEntry.line, column: entry.column),
          null);
    }
  }
}

/// Returns a terse human-readable string for a mapping from a source
/// [SourceLocation] to a target [SourceLocation].
String _mapping(SourceLocation source, SourceLocation target) =>
    "${_location(source)} to ${_location(target)}";

/// Returns a terse human-readable string for a [SourceLocation].
String _location(SourceLocation location) =>
    "${location.line}:${location.column}";

/// Returns a human-readable string representation of [map] between [sourceText]
/// and [targetText].
String _mapToString(SingleMapping map, String sourceText, String targetText) {
  var entries = _entriesForMap(map);
  var entriesInSourceOrder = entries.toList()
    ..sort((entry1, entry2) => entry1.source.compareTo(entry2.source));

  // A map from lines and columns in [sourceText] to the names of the entries
  // with those source locations.
  var entryNames = <Tuple2<int, int>, String>{};
  var i = 0;
  for (var entry in entriesInSourceOrder) {
    entryNames.putIfAbsent(
        Tuple2(entry.source.line, entry.source.column), () => (++i).toString());
  }

  var sourceScanner = LineScanner(sourceText);
  var sourceBuffer = StringBuffer();
  while (!sourceScanner.isDone) {
    var name = entryNames[Tuple2(sourceScanner.line, sourceScanner.column)];
    if (name != null) sourceBuffer.write("{{$name}}");
    sourceBuffer.writeCharCode(sourceScanner.readChar());
  }

  var targetScanner = LineScanner(targetText);
  var targetBuffer = StringBuffer();
  var entryIter = entries.iterator..moveNext();
  while (!targetScanner.isDone) {
    var entry = entryIter.current;
    if (entry != null &&
        targetScanner.line == entry.target.line &&
        targetScanner.column == entry.target.column) {
      var name = entryNames[Tuple2(entry.source.line, entry.source.column)];
      targetBuffer.write("{{$name}}");
      entryIter.moveNext();
    }

    targetBuffer.writeCharCode(targetScanner.readChar());
  }

  return sourceBuffer.toString() +
      "\n\n" +
      "v" * 50 +
      "\n\n" +
      targetBuffer.toString();
}
