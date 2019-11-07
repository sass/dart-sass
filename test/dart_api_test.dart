// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

void main() {
  // TODO(nweiz): test SASS_PATH when dart-lang/sdk#28160 is fixed.

  group("importers", () {
    test("is used to resolve imports", () async {
      await d.dir("subdir", [d.file("subtest.scss", "a {b: c}")]).create();
      await d.file("test.scss", '@import "subtest.scss";').create();

      var css = compile(d.path("test.scss"),
          importers: [FilesystemImporter(d.path('subdir'))]);
      expect(css, equals("a {\n  b: c;\n}"));
    });

    test("are checked in order", () async {
      await d
          .dir("first", [d.file("other.scss", "a {b: from-first}")]).create();
      await d
          .dir("second", [d.file("other.scss", "a {b: from-second}")]).create();
      await d.file("test.scss", '@import "other";').create();

      var css = compile(d.path("test.scss"), importers: [
        FilesystemImporter(d.path('first')),
        FilesystemImporter(d.path('second'))
      ]);
      expect(css, equals("a {\n  b: from-first;\n}"));
    });
  });

  group("loadPaths", () {
    test("is used to import file: URLs", () async {
      await d.dir("subdir", [d.file("subtest.scss", "a {b: c}")]).create();
      await d.file("test.scss", '@import "subtest.scss";').create();

      var css = compile(d.path("test.scss"), loadPaths: [d.path('subdir')]);
      expect(css, equals("a {\n  b: c;\n}"));
    });

    test("can import partials", () async {
      await d.dir("subdir", [d.file("_subtest.scss", "a {b: c}")]).create();
      await d.file("test.scss", '@import "subtest.scss";').create();

      var css = compile(d.path("test.scss"), loadPaths: [d.path('subdir')]);
      expect(css, equals("a {\n  b: c;\n}"));
    });

    test("adds a .scss extension", () async {
      await d.dir("subdir", [d.file("subtest.scss", "a {b: c}")]).create();
      await d.file("test.scss", '@import "subtest";').create();

      var css = compile(d.path("test.scss"), loadPaths: [d.path('subdir')]);
      expect(css, equals("a {\n  b: c;\n}"));
    });

    test("adds a .sass extension", () async {
      await d.dir("subdir", [d.file("subtest.sass", "a\n  b: c")]).create();
      await d.file("test.scss", '@import "subtest";').create();

      var css = compile(d.path("test.scss"), loadPaths: [d.path('subdir')]);
      expect(css, equals("a {\n  b: c;\n}"));
    });

    test("are checked in order", () async {
      await d
          .dir("first", [d.file("other.scss", "a {b: from-first}")]).create();
      await d
          .dir("second", [d.file("other.scss", "a {b: from-second}")]).create();
      await d.file("test.scss", '@import "other";').create();

      var css = compile(d.path("test.scss"),
          loadPaths: [d.path('first'), d.path('second')]);
      expect(css, equals("a {\n  b: from-first;\n}"));
    });
  });

  group("packageResolver", () {
    test("is used to import package: URLs", () async {
      await d.dir("subdir", [d.file("test.scss", "a {b: 1 + 2}")]).create();

      await d
          .file("test.scss", '@import "package:fake_package/test";')
          .create();
      var resolver = SyncPackageResolver.config(
          {"fake_package": p.toUri(d.path('subdir'))});

      var css = compile(d.path("test.scss"), packageResolver: resolver);
      expect(css, equals("a {\n  b: 3;\n}"));
    });

    test("can resolve relative paths in a package", () async {
      await d.dir("subdir", [
        d.file("test.scss", "@import 'other'"),
        d.file("_other.scss", "a {b: 1 + 2}"),
      ]).create();

      await d
          .file("test.scss", '@import "package:fake_package/test";')
          .create();
      var resolver = SyncPackageResolver.config(
          {"fake_package": p.toUri(d.path('subdir'))});

      var css = compile(d.path("test.scss"), packageResolver: resolver);
      expect(css, equals("a {\n  b: 3;\n}"));
    });

    test("doesn't import a package URL from a missing package", () async {
      await d
          .file("test.scss", '@import "package:fake_package/test_aux";')
          .create();
      var resolver = SyncPackageResolver.config({});

      expect(() => compile(d.path("test.scss"), packageResolver: resolver),
          throwsA(const TypeMatcher<SassRuntimeException>()));
    });
  });

  group("import precedence", () {
    test("relative imports take precedence over importers", () async {
      await d.dir(
          "subdir", [d.file("other.scss", "a {b: from-load-path}")]).create();
      await d.file("other.scss", "a {b: from-relative}").create();
      await d.file("test.scss", '@import "other";').create();

      var css = compile(d.path("test.scss"),
          importers: [FilesystemImporter(d.path('subdir'))]);
      expect(css, equals("a {\n  b: from-relative;\n}"));
    });

    test("the original importer takes precedence over other importers",
        () async {
      await d.dir(
          "original", [d.file("other.scss", "a {b: from-original}")]).create();
      await d
          .dir("other", [d.file("other.scss", "a {b: from-other}")]).create();

      var css = compileString('@import "other";',
          importer: FilesystemImporter(d.path('original')),
          url: p.toUri(d.path('original/test.scss')),
          importers: [FilesystemImporter(d.path('other'))]);
      expect(css, equals("a {\n  b: from-original;\n}"));
    });

    test("importers take precedence over load paths", () async {
      await d.dir("load-path",
          [d.file("other.scss", "a {b: from-load-path}")]).create();
      await d.dir(
          "importer", [d.file("other.scss", "a {b: from-importer}")]).create();
      await d.file("test.scss", '@import "other";').create();

      var css = compile(d.path("test.scss"),
          importers: [FilesystemImporter(d.path('importer'))],
          loadPaths: [d.path('load-path')]);
      expect(css, equals("a {\n  b: from-importer;\n}"));
    });

    test("importers take precedence over packageResolver", () async {
      await d.dir("package",
          [d.file("other.scss", "a {b: from-package-resolver}")]).create();
      await d.dir(
          "importer", [d.file("other.scss", "a {b: from-importer}")]).create();
      await d
          .file("test.scss", '@import "package:fake_package/other";')
          .create();

      var css = compile(d.path("test.scss"),
          importers: [
            PackageImporter(SyncPackageResolver.config(
                {"fake_package": p.toUri(d.path('importer'))}))
          ],
          packageResolver: SyncPackageResolver.config(
              {"fake_package": p.toUri(d.path('package'))}));
      expect(css, equals("a {\n  b: from-importer;\n}"));
    });
  });

  group("charset", () {
    group("= true", () {
      test("doesn't emit @charset for a pure-ASCII stylesheet", () {
        expect(compileString("a {b: c}"), equals("""
a {
  b: c;
}"""));
      });

      test("emits @charset with expanded output", () async {
        expect(compileString("a {b: 👭}"), equals("""
@charset "UTF-8";
a {
  b: 👭;
}"""));
      });

      test("emits a BOM with compressed output", () async {
        expect(compileString("a {b: 👭}", style: OutputStyle.compressed),
            equals("\u{FEFF}a{b:👭}"));
      });
    });

    group("= false", () {
      test("doesn't emit @charset with expanded output", () async {
        expect(compileString("a {b: 👭}", charset: false), equals("""
a {
  b: 👭;
}"""));
      });

      test("emits a BOM with compressed output", () async {
        expect(
            compileString("a {b: 👭}",
                charset: false, style: OutputStyle.compressed),
            equals("a{b:👭}"));
      });
    });
  });
}
