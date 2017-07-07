// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(const ['node'])

import 'dart:async';
import 'dart:convert';

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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

    group("throws an error that", () {
      setUp(() => writeTextFile(sassPath, 'a {b: }'));

      test("has a useful toString", () {
        var error = _renderSyncError(new RenderOptions(file: sassPath));
        expect(error.toString(), equals("Error: Expected expression."));
      });

      test("has a useful message", () {
        var error = _renderSyncError(new RenderOptions(file: sassPath));
        expect(error.message, equals("Expected expression."));
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
      expect(error.toString(), equals("Error: Expected expression."));
    });
  });
}

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
