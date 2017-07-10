// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(const ['node'])

import 'dart:async';
import 'dart:convert';

import 'package:js/js.dart';
import 'package:test/test.dart';

import 'package:sass/src/util/path.dart';

import 'ensure_npm_package.dart';
import 'hybrid.dart';
import 'node_api.dart';

String sandbox;
String sassPath;

void main() {
  setUpAll(ensureNpmPackage);

  setUp(() async {
    sandbox = await createTempDir();
    sassPath = p.join(sandbox, 'test.scss');
    await writeTextFile(sassPath, 'a {b: c}');
  });

  tearDown(() async {
    if (sandbox != null) await deleteDirectory(sandbox);
  });

  group("renderSync()", () {
    test("renders a file", () {
      expect(_renderSync(new RenderOptions(file: sassPath)), equals('''
a {
  b: c;
}'''));
    });

    test("renders a file with the indented syntax", () async {
      var indentedPath = p.join(sandbox, 'test.sass');
      await writeTextFile(indentedPath, 'a\n  b: c');
      expect(_renderSync(new RenderOptions(file: indentedPath)), equals('''
a {
  b: c;
}'''));
    });

    test("supports relative imports for a file", () async {
      var importerPath = p.join(sandbox, 'importer.scss');
      await writeTextFile(importerPath, '@import "test"');
      expect(_renderSync(new RenderOptions(file: importerPath)), equals('''
a {
  b: c;
}'''));
    });

    test("renders a string", () {
      expect(_renderSync(new RenderOptions(data: "a {b: c}")), equals('''
a {
  b: c;
}'''));
    });

    test("data and file may not both be set", () {
      var error =
          _renderSyncError(new RenderOptions(data: "x {y: z}", file: sassPath));
      expect(error.toString(),
          contains('options.data and options.file may not both be set.'));
    });

    test("one of data and file must be set", () {
      var error = _renderSyncError(new RenderOptions());
      expect(error.toString(),
          contains('Either options.data or options.file must be set.'));
    });

    test("supports load paths", () {
      expect(
          _renderSync(new RenderOptions(
              data: "@import 'test'", includePaths: [sandbox])),
          equals('''
a {
  b: c;
}'''));
    });

    test("supports relative paths in preference to load paths", () async {
      await createDirectory(p.join(sandbox, 'sub'));
      var subPath = p.join(sandbox, 'sub/test.scss');
      await writeTextFile(subPath, 'x {y: z}');

      var importerPath = p.join(sandbox, 'importer.scss');
      await writeTextFile(importerPath, '@import "test"');

      expect(
          _renderSync(new RenderOptions(
              file: importerPath, includePaths: [p.join(sandbox, 'sub')])),
          equals('''
a {
  b: c;
}'''));
    });

    test("can render the indented syntax", () {
      expect(
          _renderSync(
              new RenderOptions(data: "a\n  b: c", indentedSyntax: true)),
          equals('''
a {
  b: c;
}'''));
    });

    test("the indented syntax flag takes precedence over the file extension",
        () async {
      var scssPath = p.join(sandbox, 'test.scss');
      await writeTextFile(scssPath, 'a\n  b: c');
      expect(
          _renderSync(new RenderOptions(file: scssPath, indentedSyntax: true)),
          equals('''
a {
  b: c;
}'''));
    });

    test("supports the expanded output style", () {
      expect(
          _renderSync(
              new RenderOptions(file: sassPath, outputStyle: 'expanded')),
          equals('''
a {
  b: c;
}'''));
    });

    test("doesn't support other output styles", () {
      var error = _renderSyncError(
          new RenderOptions(file: sassPath, outputStyle: 'nested'));
      expect(error.toString(), contains('Unsupported output style "nested".'));
    });

    test("allows tab indentation", () {
      expect(_renderSync(new RenderOptions(file: sassPath, indentType: 'tab')),
          equals('''
a {
\t\tb: c;
}'''));
    });

    test("allows unknown indentation names", () {
      expect(_renderSync(new RenderOptions(file: sassPath, indentType: 'asdf')),
          equals('''
a {
  b: c;
}'''));
    });

    group("linefeed allows", () {
      test("cr", () {
        expect(_renderSync(new RenderOptions(file: sassPath, linefeed: 'cr')),
            equals('a {\r  b: c;\r}'));
      });

      test("crlf", () {
        expect(_renderSync(new RenderOptions(file: sassPath, linefeed: 'crlf')),
            equals('a {\r\n  b: c;\r\n}'));
      });

      test("lfcr", () {
        expect(_renderSync(new RenderOptions(file: sassPath, linefeed: 'lfcr')),
            equals('a {\n\r  b: c;\n\r}'));
      });

      test("unknown names", () {
        expect(_renderSync(new RenderOptions(file: sassPath, linefeed: 'asdf')),
            equals('a {\n  b: c;\n}'));
      });
    });

    group("indentWidth allows", () {
      test("a number", () {
        expect(_renderSync(new RenderOptions(file: sassPath, indentWidth: 10)),
            equals('''
a {
          b: c;
}'''));
      });

      test("a string", () {
        expect(_renderSync(new RenderOptions(file: sassPath, indentWidth: '1')),
            equals('''
a {
 b: c;
}'''));
      });
    });

    group("the result object", () {
      test("includes the filename", () {
        var result = sass.renderSync(new RenderOptions(file: sassPath));
        expect(result.stats.entry, equals(sassPath));
      });

      test("includes data without a filename", () {
        var result = sass.renderSync(new RenderOptions(data: 'a {b: c}'));
        expect(result.stats.entry, equals('data'));
      });

      test("includes timing information", () {
        var result = sass.renderSync(new RenderOptions(file: sassPath));
        expect(result.stats.start, new isInstanceOf<int>());
        expect(result.stats.end, new isInstanceOf<int>());
        expect(result.stats.start, lessThan(result.stats.end));
        expect(result.stats.duration,
            equals(result.stats.end - result.stats.start));
      });

      group("has includedFiles which", () {
        test("contains the root path if available", () {
          var result = sass.renderSync(new RenderOptions(file: sassPath));
          expect(result.stats.includedFiles, equals([sassPath]));
        });

        test("doesn't contain the root path if it's not available", () {
          var result = sass.renderSync(new RenderOptions(data: 'a {b: c}'));
          expect(result.stats.includedFiles, isEmpty);
        });

        test("contains imported paths", () async {
          var importerPath = p.join(sandbox, 'importer.scss');
          await writeTextFile(importerPath, '@import "test"');

          var result = sass.renderSync(new RenderOptions(file: importerPath));
          expect(result.stats.includedFiles,
              unorderedEquals([importerPath, sassPath]));
        });

        test("only contains each path once", () async {
          var importerPath = p.join(sandbox, 'importer.scss');
          await writeTextFile(importerPath, '@import "test"; @import "test";');

          var result = sass.renderSync(new RenderOptions(file: importerPath));
          expect(result.stats.includedFiles,
              unorderedEquals([importerPath, sassPath]));
        });
      });
    });

    group("the error object", () {
      RenderError error;
      group("for a parse error in a file", () {
        setUp(() async {
          await writeTextFile(sassPath, "a {b: }");
          error = _renderSyncError(new RenderOptions(file: sassPath));
        });

        test("has a useful toString() and message", () async {
          expect(
              error,
              toStringAndMessageEqual("Expected expression.\n"
                  "  $sassPath 1:7  root stylesheet"));
        });

        test("has a useful formatted message", () async {
          expect(
              error.formatted,
              "Error: Expected expression.\n"
              "a {b: }\n"
              "      ^\n"
              "  $sassPath 1:7  root stylesheet");
        });

        test("sets the line, column, and filename", () {
          expect(error.line, equals(1));
          expect(error.column, equals(7));
          expect(error.file, equals(sassPath));
        });
      });

      group("for a parse error in a string", () {
        setUp(() {
          error = _renderSyncError(new RenderOptions(data: "a {b: }"));
        });

        test("has a useful toString() and message", () {
          expect(
              error,
              toStringAndMessageEqual("Expected expression.\n"
                  "  - 1:7  root stylesheet"));
        });

        test("has a useful formatted message", () {
          expect(
              error.formatted,
              "Error: Expected expression.\n"
              "a {b: }\n"
              "      ^\n"
              "  - 1:7  root stylesheet");
        });

        test("sets the line, column, and filename", () {
          expect(error.line, equals(1));
          expect(error.column, equals(7));
          expect(error.file, equals("stdin"));
        });
      });

      group("for a runtime error in a file", () {
        setUp(() async {
          await writeTextFile(sassPath, "a {b: 1 % a}");
          error = _renderSyncError(new RenderOptions(file: sassPath));
        });

        test("has a useful toString() and message", () {
          expect(
              error,
              toStringAndMessageEqual('Undefined operation "1 % a".\n'
                  '  $sassPath 1:7  root stylesheet'));
        });

        test("has a useful formatted message", () async {
          expect(
              error.formatted,
              'Error: Undefined operation "1 % a".\n'
              'a {b: 1 % a}\n'
              '      ^^^^^\n'
              '  $sassPath 1:7  root stylesheet');
        });

        test("sets the line, column, and filename", () {
          expect(error.line, equals(1));
          expect(error.column, equals(7));
          expect(error.file, equals(sassPath));
        });
      });

      group("for a runtime error in a string", () {
        setUp(() {
          error = _renderSyncError(new RenderOptions(data: "a {b: 1 % a}"));
        });

        test("has a useful toString() and message", () {
          expect(
              error,
              toStringAndMessageEqual('Undefined operation "1 % a".\n'
                  '  - 1:7  root stylesheet'));
        });

        test("has a useful formatted message", () {
          expect(
              error.formatted,
              'Error: Undefined operation "1 % a".\n'
              'a {b: 1 % a}\n'
              '      ^^^^^\n'
              '  - 1:7  root stylesheet');
        });

        test("sets the line, column, and filename", () {
          expect(error.line, equals(1));
          expect(error.column, equals(7));
          expect(error.file, equals("stdin"));
        });
      });
    });
  });

  group("render()", () {
    test("renders a file", () async {
      expect(await _render(new RenderOptions(file: sassPath)), equals('''
a {
  b: c;
}'''));
    });

    test("throws an error that has a useful toString", () async {
      await writeTextFile(sassPath, 'a {b: }');

      var error = await _renderError(new RenderOptions(file: sassPath));
      expect(
          error.toString(),
          equals("Error: Expected expression.\n"
              "  $sassPath 1:7  root stylesheet"));
    });
  });
}

/// Validates that a [RenderError]'s `toString()` and `message` both equal
/// [text].
Matcher toStringAndMessageEqual(String text) => predicate((error) {
      expect(error.toString(), equals("Error: $text"));
      expect(error.message, equals(text));
      return true;
    });

/// Returns the result of rendering via [options] as a string.
Future<String> _render(RenderOptions options) {
  var completer = new Completer<String>();
  sass.render(options, allowInterop((error, result) {
    expect(error, isNull);
    completer.complete(UTF8.decode(result.css));
  }));
  return completer.future;
}

/// Asserts that rendering via [options] produces an error, and returns that
/// error.
Future<RenderError> _renderError(RenderOptions options) {
  var completer = new Completer<RenderError>();
  sass.render(options, allowInterop((error, result) {
    expect(result, isNull);
    completer.complete(error as RenderError);
  }));
  return completer.future;
}

/// Returns the result of rendering via [options] as a string.
String _renderSync(RenderOptions options) =>
    UTF8.decode(sass.renderSync(options).css);

/// Asserts that rendering via [options] produces an error, and returns that
/// error.
RenderError _renderSyncError(RenderOptions options) {
  try {
    sass.renderSync(options);
  } catch (error) {
    return error as RenderError;
  }

  throw "Expected renderSync() to throw an error.";
}
