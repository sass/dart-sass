// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:async';

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:sass/src/io.dart';
import 'package:sass/src/value/number.dart';

import '../ensure_npm_package.dart';
import '../hybrid.dart';
import 'api.dart';
import 'utils.dart';

String sassPath;

void main() {
  setUpAll(ensureNpmPackage);
  useSandbox();

  setUp(() async {
    sassPath = p.join(sandbox, 'test.scss');
    await writeTextFile(sassPath, 'a {b: c}');
  });

  test("can import a file by contents", () {
    expect(
        renderSync(RenderOptions(
            data: "@import 'foo'",
            importer: allowInterop((void _, void __) =>
                NodeImporterResult(contents: 'a {b: c}')))),
        equalsIgnoringWhitespace('a { b: c; }'));
  });

  test("imports cascade through importers", () {
    expect(
        renderSync(RenderOptions(data: "@import 'foo'", importer: [
          allowInterop((Object url, void _) {
            if (url != "foo") return null;
            return NodeImporterResult(contents: '@import "bar"');
          }),
          allowInterop((Object url, void _) {
            if (url != "bar") return null;
            return NodeImporterResult(contents: '@import "baz"');
          }),
          allowInterop((Object url, void _) {
            if (url != "baz") return null;
            return NodeImporterResult(contents: 'a {b: c}');
          })
        ])),
        equalsIgnoringWhitespace('a { b: c; }'));
  });

  test("an empty object means an empty file", () {
    expect(
        renderSync(RenderOptions(
            data: "@import 'foo'",
            importer: allowInterop((void _, void __) => NodeImporterResult()))),
        equalsIgnoringWhitespace(''));
  });

  group("import precedence:", () {
    group("in sandbox dir", () {
      setUp(runTestInSandbox);

      test("relative file is #1", () async {
        var subDir = p.join(sandbox, 'sub');
        await createDirectory(subDir);
        await writeTextFile(p.join(subDir, 'test.scss'), 'x {y: z}');

        var basePath = p.join(subDir, 'base.scss');
        await writeTextFile(basePath, '@import "test"');

        expect(
            renderSync(RenderOptions(
                file: basePath,
                importer: allowInterop((void _, void __) =>
                    NodeImporterResult(contents: "q {r: s}")))),
            equalsIgnoringWhitespace('x { y: z; }'));
      });

      test("importer is #2", () async {
        expect(
            renderSync(RenderOptions(
                data: '@import "test"',
                importer: allowInterop((void _, void __) =>
                    NodeImporterResult(contents: "x {y: z}")))),
            equalsIgnoringWhitespace('x { y: z; }'));
      });

      test("CWD is #3", () async {
        var subDir = p.join(sandbox, 'sub');
        await createDirectory(subDir);
        await writeTextFile(p.join(subDir, 'test.scss'), 'x {y: z}');

        expect(
            renderSync(
                RenderOptions(data: '@import "test"', includePaths: [subDir])),
            equalsIgnoringWhitespace('a { b: c; }'));
      });
    });

    test("include path is #4", () async {
      var subDir = p.join(sandbox, 'sub');
      await createDirectory(subDir);
      await writeTextFile(p.join(subDir, 'test.scss'), 'x {y: z}');

      withSassPath([subDir], () {
        expect(
            renderSync(
                RenderOptions(data: '@import "test"', includePaths: [sandbox])),
            equalsIgnoringWhitespace('a { b: c; }'));
      });
    });
  });

  group("with a file redirect", () {
    test("imports the chosen file", () {
      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop(
                  (void _, void __) => NodeImporterResult(file: sassPath)))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    test("supports the indented syntax", () async {
      await writeTextFile(p.join(sandbox, 'target.sass'), 'a\n  b: c');

      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __) =>
                  NodeImporterResult(file: p.join(sandbox, 'target.sass'))))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    test("supports plain CSS", () async {
      // An import in plain CSS is only ever interpreted as a plain CSS import.
      await writeTextFile(p.join(sandbox, 'target.css'), "@import 'bar'");

      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __) =>
                  NodeImporterResult(file: p.join(sandbox, 'target.css'))))),
          equalsIgnoringWhitespace('@import "bar";'));
    });

    test("supports partials", () async {
      await writeTextFile(p.join(sandbox, '_target.scss'), 'a {b: c}');

      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __) =>
                  NodeImporterResult(file: p.join(sandbox, 'target.scss'))))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    test("supports import-only files", () async {
      await writeTextFile(p.join(sandbox, 'target.scss'), 'a {b: regular}');
      await writeTextFile(
          p.join(sandbox, 'target.import.scss'), 'a {b: import-only}');

      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __) =>
                  NodeImporterResult(file: p.join(sandbox, 'target.scss'))))),
          equalsIgnoringWhitespace('a { b: import-only; }'));
    });

    test("supports mixed `@use` and `@import`", () async {
      await writeTextFile(p.join(sandbox, 'target.scss'), 'a {b: regular}');
      await writeTextFile(
          p.join(sandbox, 'target.import.scss'), 'a {b: import-only}');

      expect(
          renderSync(RenderOptions(
              data: "@use 'foo'; @import 'foo';",
              importer: allowInterop((void _, void __) =>
                  NodeImporterResult(file: p.join(sandbox, 'target.scss'))))),
          equalsIgnoringWhitespace('a { b: regular; } a { b: import-only; }'));
    });

    test("may be extensionless", () async {
      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __) =>
                  NodeImporterResult(file: p.withoutExtension(sassPath))))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    test("is resolved relative to the base file", () async {
      var basePath = p.join(sandbox, 'base.scss');
      await writeTextFile(basePath, '@import "foo"');

      expect(
          renderSync(RenderOptions(
              file: basePath,
              importer: allowInterop(
                  (void _, void __) => NodeImporterResult(file: 'test.scss')))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    test("puts the absolute path in includedFiles", () async {
      var basePath = p.join(sandbox, 'base.scss');
      await writeTextFile(basePath, '@import "foo"');

      var result = sass.renderSync(RenderOptions(
          file: basePath,
          importer: allowInterop(
              (void _, void __) => NodeImporterResult(file: 'test'))));
      expect(result.stats.includedFiles, equals([basePath, sassPath]));
    });

    test("is resolved relative to include paths", () async {
      expect(
          renderSync(RenderOptions(
              data: "@import 'foo'",
              includePaths: [sandbox],
              importer: allowInterop(
                  (void _, void __) => NodeImporterResult(file: 'test')))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    test("relative to the base file takes precedence over include paths",
        () async {
      var basePath = p.join(sandbox, 'base.scss');
      await writeTextFile(basePath, '@import "foo"');

      var subDir = p.join(sandbox, 'sub');
      await createDirectory(subDir);
      await writeTextFile(p.join(subDir, 'test.scss'), 'x {y: z}');

      expect(
          renderSync(RenderOptions(
              file: basePath,
              includePaths: [subDir],
              importer: allowInterop(
                  (void _, void __) => NodeImporterResult(file: 'test')))),
          equalsIgnoringWhitespace('a { b: c; }'));
    });

    group("in the sandbox directory", () {
      String oldWorkingDirectory;
      setUp(() {
        oldWorkingDirectory = currentPath;
        chdir(sandbox);
      });

      tearDown(() => chdir(oldWorkingDirectory));

      test("is resolved relative to the CWD", () {
        expect(
            renderSync(RenderOptions(
                data: "@import 'foo'",
                importer: allowInterop((void _, void __) =>
                    NodeImporterResult(file: 'test.scss')))),
            equalsIgnoringWhitespace('a { b: c; }'));
      });

      test("file-relative takes precedence over the CWD", () async {
        await createDirectory(p.join(sandbox, 'sub'));
        var basePath = p.join(sandbox, 'sub', 'base.scss');
        await writeTextFile(basePath, '@import "foo"');
        await writeTextFile(p.join(sandbox, 'sub', 'test.scss'), 'x {y: z}');

        expect(
            renderSync(RenderOptions(
                file: basePath,
                importer: allowInterop((void _, void __) =>
                    NodeImporterResult(file: 'test.scss')))),
            equalsIgnoringWhitespace('x { y: z; }'));
      });

      test("the CWD takes precedence over include paths", () async {
        var basePath = p.join(sandbox, 'base.scss');
        await writeTextFile(basePath, '@import "test"');
        var subDir = p.join(sandbox, 'sub');
        await createDirectory(subDir);
        await writeTextFile(p.join(subDir, 'test.scss'), 'x {y: z}');

        expect(
            renderSync(RenderOptions(
                file: basePath,
                includePaths: [subDir],
                importer: allowInterop((void _, void __) =>
                    NodeImporterResult(file: 'test.scss')))),
            equalsIgnoringWhitespace('a { b: c; }'));
      });
    });
  });

  group("the imported URL", () {
    test("is the exact imported text", () {
      renderSync(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop(expectAsync2((url, _) {
            expect(url, equals('foo'));
            return NodeImporterResult(contents: '');
          }))));
    });

    // Regression test for #246.
    test("doesn't remove ./", () {
      renderSync(RenderOptions(
          data: "@import './foo'",
          importer: allowInterop(expectAsync2((url, _) {
            expect(url, equals('./foo'));
            return NodeImporterResult(contents: '');
          }))));
    });

    test("isn't resolved relative to the current file", () {
      renderSync(RenderOptions(
          data: "@import 'foo/bar'",
          importer: allowInterop(expectAsync2((url, _) {
            if (url == 'foo/bar') {
              return NodeImporterResult(contents: "@import 'baz'");
            } else {
              expect(url, equals('baz'));
              return NodeImporterResult(contents: "");
            }
          }, count: 2))));
    });

    test("is added to includedFiles", () {
      var result = sass.renderSync(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop(expectAsync2((void _, void __) {
            return NodeImporterResult(contents: '');
          }))));
      expect(result.stats.includedFiles, equals(['foo']));
    });
  });

  group("the previous URL", () {
    test("is an absolute path for stylesheets from the filesystem", () async {
      var importPath = p.join(sandbox, 'import.scss');
      await writeTextFile(importPath, "@import 'foo'");

      renderSync(RenderOptions(
          file: importPath,
          importer: allowInterop(expectAsync2((_, prev) {
            expect(prev, equals(p.absolute(importPath)));
            return NodeImporterResult(contents: '');
          }))));
    });

    test("is an absolute path for stylesheets redirected to the filesystem",
        () async {
      var import1Path = p.join(sandbox, 'import1.scss');
      await writeTextFile(import1Path, "@import 'foo'");

      var import2Path = p.join(sandbox, 'import2.scss');
      await writeTextFile(import2Path, "@import 'baz'");

      renderSync(RenderOptions(
          file: import1Path,
          importer: allowInterop(expectAsync2((url, prev) {
            if (url == 'foo') {
              return NodeImporterResult(file: 'import2');
            } else {
              expect(url, equals('baz'));
              expect(prev, equals(import2Path));
              return NodeImporterResult(contents: "");
            }
          }, count: 2))));
    });

    test('is "stdin" for string stylesheets', () async {
      renderSync(RenderOptions(
          data: '@import "foo"',
          importer: allowInterop(expectAsync2((_, prev) {
            expect(prev, equals('stdin'));
            return NodeImporterResult(contents: '');
          }))));
    });

    test("is the imported string for imports from importers", () async {
      renderSync(RenderOptions(data: '@import "foo"', importer: [
        allowInterop(expectAsync2((url, _) {
          if (url != "foo") return null;
          return NodeImporterResult(contents: '@import "bar"');
        }, count: 2)),
        allowInterop(expectAsync2((url, prev) {
          expect(url, equals("bar"));
          expect(prev, equals("foo"));
          return NodeImporterResult(contents: '');
        }))
      ]));
    });
  });

  group("this", () {
    test('includes default option values', () {
      renderSync(RenderOptions(
          data: '@import "foo"',
          importer: allowInteropCaptureThis(
              expectAsync3((RenderContext this_, _, __) {
            var options = this_.options;
            expect(options.includePaths, equals(p.current));
            expect(options.precision, equals(SassNumber.precision));
            expect(options.style, equals(1));
            expect(options.indentType, equals(0));
            expect(options.indentWidth, equals(2));
            expect(options.linefeed, equals('\n'));

            return NodeImporterResult(contents: '');
          }))));
    });

    test('includes the data when rendering via data', () {
      renderSync(RenderOptions(
          data: '@import "foo"',
          importer: allowInteropCaptureThis(
              expectAsync3((RenderContext this_, _, __) {
            expect(this_.options.data, equals('@import "foo"'));
            expect(this_.options.file, isNull);
            return NodeImporterResult(contents: '');
          }))));
    });

    test('includes the filename when rendering via file', () async {
      await writeTextFile(sassPath, '@import "foo"');
      renderSync(RenderOptions(
          file: sassPath,
          importer: allowInteropCaptureThis(
              expectAsync3((RenderContext this_, _, __) {
            expect(this_.options.data, isNull);
            expect(this_.options.file, equals(sassPath));
            return NodeImporterResult(contents: '');
          }))));
    });

    test('includes other include paths', () {
      renderSync(RenderOptions(
          data: '@import "foo"',
          includePaths: [sandbox],
          importer: allowInteropCaptureThis(
              expectAsync3((RenderContext this_, _, __) {
            expect(this_.options.includePaths,
                equals("${p.current}${isWindows ? ';' : ':'}$sandbox"));
            return NodeImporterResult(contents: '');
          }))));
    });

    group('can override', () {
      test('indentWidth', () {
        renderSync(RenderOptions(
            data: '@import "foo"',
            indentWidth: 5,
            importer: allowInteropCaptureThis(
                expectAsync3((RenderContext this_, _, __) {
              expect(this_.options.indentWidth, equals(5));
              return NodeImporterResult(contents: '');
            }))));
      });

      test('indentType', () {
        renderSync(RenderOptions(
            data: '@import "foo"',
            indentType: 'tab',
            importer: allowInteropCaptureThis(
                expectAsync3((RenderContext this_, _, __) {
              expect(this_.options.indentType, equals(1));
              return NodeImporterResult(contents: '');
            }))));
      });

      test('linefeed', () {
        renderSync(RenderOptions(
            data: '@import "foo"',
            linefeed: 'cr',
            importer: allowInteropCaptureThis(
                expectAsync3((RenderContext this_, _, __) {
              expect(this_.options.linefeed, equals('\r'));
              return NodeImporterResult(contents: '');
            }))));
      });
    });

    test('has a circular reference', () {
      renderSync(RenderOptions(
          data: '@import "foo"',
          importer: allowInteropCaptureThis(
              expectAsync3((RenderContext this_, _, __) {
            expect(this_.options.context, same(this_));
            return NodeImporterResult(contents: '');
          }))));
    });

    group("includes render stats with", () {
      test('a start time', () {
        var start = DateTime.now();
        renderSync(RenderOptions(
            data: '@import "foo"',
            importer: allowInteropCaptureThis(
                expectAsync3((RenderContext this_, _, __) {
              expect(this_.options.result.stats.start,
                  greaterThanOrEqualTo(start.millisecondsSinceEpoch));
              return NodeImporterResult(contents: '');
            }))));
      });

      test('a data entry', () {
        renderSync(RenderOptions(
            data: '@import "foo"',
            importer: allowInteropCaptureThis(
                expectAsync3((RenderContext this_, _, __) {
              expect(this_.options.result.stats.entry, equals('data'));
              return NodeImporterResult(contents: '');
            }))));
      });

      test('a file entry', () async {
        await writeTextFile(sassPath, '@import "foo"');
        renderSync(RenderOptions(
            file: sassPath,
            importer: allowInteropCaptureThis(
                expectAsync3((RenderContext this_, _, __) {
              expect(this_.options.result.stats.entry, equals(sassPath));
              return NodeImporterResult(contents: '');
            }))));
      });
    });
  });

  group("gracefully handles an error when", () {
    test("an importer redirects to a non-existent file", () {
      var error = renderSyncError(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop((void _, void __) =>
              NodeImporterResult(file: '_does_not_exist'))));
      expect(
          error,
          toStringAndMessageEqual("Can't find stylesheet to import.\n"
              "  ╷\n"
              "1 │ @import 'foo'\n"
              "  │         ^^^^^\n"
              "  ╵\n"
              "  stdin 1:9  root stylesheet"));
    });

    test("an error is returned", () {
      var error = renderSyncError(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop((void _, void __) => JSError("oh no"))));

      expect(
          error,
          toStringAndMessageEqual("oh no\n"
              "  ╷\n"
              "1 │ @import 'foo'\n"
              "  │         ^^^^^\n"
              "  ╵\n"
              "  stdin 1:9  root stylesheet"));
    });

    // TODO(nweiz): Test returning an error subclass when dart-lang/sdk#31168 is
    // fixed.

    test("null is returned", () {
      var error = renderSyncError(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop((void _, void __) => null)));
      expect(
          error,
          toStringAndMessageEqual("Can't find stylesheet to import.\n"
              "  ╷\n"
              "1 │ @import 'foo'\n"
              "  │         ^^^^^\n"
              "  ╵\n"
              "  stdin 1:9  root stylesheet"));
    });

    test("undefined is returned", () {
      var error = renderSyncError(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop((void _, void __) => undefined)));
      expect(
          error,
          toStringAndMessageEqual("Can't find stylesheet to import.\n"
              "  ╷\n"
              "1 │ @import 'foo'\n"
              "  │         ^^^^^\n"
              "  ╵\n"
              "  stdin 1:9  root stylesheet"));
    });

    test("an unrecognized value is returned", () {
      var error = renderSyncError(RenderOptions(
          data: "@import 'foo'",
          importer: allowInterop((void _, void __) => 10)));
      expect(
          error,
          toStringAndMessageEqual("Can't find stylesheet to import.\n"
              "  ╷\n"
              "1 │ @import 'foo'\n"
              "  │         ^^^^^\n"
              "  ╵\n"
              "  stdin 1:9  root stylesheet"));
    });
  });

  group("render()", () {
    test("supports asynchronous importers", () {
      expect(
          render(RenderOptions(
              data: "@import 'foo'",
              importer:
                  allowInterop((void _, void __, void done(Object result)) {
                Timer(Duration.zero, () {
                  done(NodeImporterResult(contents: 'a {b: c}'));
                });
              }))),
          completion(equalsIgnoringWhitespace('a { b: c; }')));
    });

    test("supports asynchronous errors", () {
      expect(
          renderError(RenderOptions(
              data: "@import 'foo'",
              importer:
                  allowInterop((void _, void __, void done(Object result)) {
                Timer(Duration.zero, () {
                  done(JSError('oh no'));
                });
              }))),
          completion(toStringAndMessageEqual("oh no\n"
              "  ╷\n"
              "1 │ @import 'foo'\n"
              "  │         ^^^^^\n"
              "  ╵\n"
              "  stdin 1:9  root stylesheet")));
    });

    test("supports synchronous importers", () {
      expect(
          render(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __, void ___) =>
                  NodeImporterResult(contents: 'a {b: c}')))),
          completion(equalsIgnoringWhitespace('a { b: c; }')));
    });

    test("supports synchronous null returns", () {
      expect(
          renderError(RenderOptions(
              data: "@import 'foo'",
              importer: allowInterop((void _, void __, void ___) => jsNull))),
          completion(
              toStringAndMessageEqual("Can't find stylesheet to import.\n"
                  "  ╷\n"
                  "1 │ @import 'foo'\n"
                  "  │         ^^^^^\n"
                  "  ╵\n"
                  "  stdin 1:9  root stylesheet")));
    });

    group("with fibers", () {
      setUpAll(() {
        try {
          fiber;
        } catch (_) {
          throw "Can't load fibers package.\n"
              "Run pub run grinder before-test.";
        }
      });

      test("supports asynchronous importers", () {
        expect(
            render(RenderOptions(
                data: "@import 'foo'",
                importer:
                    allowInterop((void _, void __, void done(Object result)) {
                  Timer(Duration.zero, () {
                    done(NodeImporterResult(contents: 'a {b: c}'));
                  });
                }),
                fiber: fiber)),
            completion(equalsIgnoringWhitespace('a { b: c; }')));
      });

      test("supports synchronous calls to done", () {
        expect(
            render(RenderOptions(
                data: "@import 'foo'",
                importer:
                    allowInterop((void _, void __, void done(Object result)) {
                  done(NodeImporterResult(contents: 'a {b: c}'));
                }),
                fiber: fiber)),
            completion(equalsIgnoringWhitespace('a { b: c; }')));
      });

      test("supports synchronous importers", () {
        expect(
            render(RenderOptions(
                data: "@import 'foo'",
                importer: allowInterop((void _, void __, void ___) {
                  return NodeImporterResult(contents: 'a {b: c}');
                }),
                fiber: fiber)),
            completion(equalsIgnoringWhitespace('a { b: c; }')));
      });

      test("supports asynchronous errors", () {
        expect(
            renderError(RenderOptions(
                data: "@import 'foo'",
                importer:
                    allowInterop((void _, void __, void done(Object result)) {
                  Timer(Duration.zero, () {
                    done(JSError('oh no'));
                  });
                }),
                fiber: fiber)),
            completion(toStringAndMessageEqual("oh no\n"
                "  ╷\n"
                "1 │ @import 'foo'\n"
                "  │         ^^^^^\n"
                "  ╵\n"
                "  stdin 1:9  root stylesheet")));
      });

      test("supports synchronous null returns", () {
        expect(
            renderError(RenderOptions(
                data: "@import 'foo'",
                importer: allowInterop((void _, void __, void ___) => jsNull),
                fiber: fiber)),
            completion(
                toStringAndMessageEqual("Can't find stylesheet to import.\n"
                    "  ╷\n"
                    "1 │ @import 'foo'\n"
                    "  │         ^^^^^\n"
                    "  ╵\n"
                    "  stdin 1:9  root stylesheet")));
      });
    });
  });
}
