// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:source_maps/source_maps.dart' as source_maps;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:sass/src/embedded/embedded_sass.pb.dart';
import 'package:sass/src/embedded/utils.dart';

import 'embedded_process.dart';
import 'utils.dart';

void main() {
  late EmbeddedProcess process;
  setUp(() async {
    process = await EmbeddedProcess.start();
  });

  group("emits a protocol error", () {
    test("for a response without a corresponding request ID", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = await getCanonicalizeRequest(process);
      process.send(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = request.id + 1));

      await expectParamsError(
          process,
          errorId,
          "Response ID ${request.id + 1} doesn't match any outstanding "
          "requests in compilation $defaultCompilationId.");
      await process.shouldExit(76);
    });

    test("for a response that doesn't match the request type", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = await getCanonicalizeRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()..id = request.id));

      await expectParamsError(
          process,
          errorId,
          "Request ID ${request.id} doesn't match response type "
          "InboundMessage_ImportResponse in compilation "
          "$defaultCompilationId.");
      await process.shouldExit(76);
    });

    test("for an unset importer", () async {
      process.send(compileString("a {b: c}",
          importers: [InboundMessage_CompileRequest_Importer()]));
      await expectParamsError(
          process, errorId, "Missing mandatory field Importer.importer");
      await process.shouldExit(76);
    });

    group("for an importer with nonCanonicalScheme set:", () {
      test("path", () async {
        process.send(compileString("a {b: c}", importers: [
          InboundMessage_CompileRequest_Importer(
              path: "somewhere", nonCanonicalScheme: ["u"])
        ]));
        await expectParamsError(
            process,
            errorId,
            "Importer.non_canonical_scheme may only be set along with "
            "Importer.importer.importer_id");
        await process.shouldExit(76);
      });

      test("file importer", () async {
        process.send(compileString("a {b: c}", importers: [
          InboundMessage_CompileRequest_Importer(
              fileImporterId: 1, nonCanonicalScheme: ["u"])
        ]));
        await expectParamsError(
            process,
            errorId,
            "Importer.non_canonical_scheme may only be set along with "
            "Importer.importer.importer_id");
        await process.shouldExit(76);
      });

      test("unset", () async {
        process.send(compileString("a {b: c}",
            importer: InboundMessage_CompileRequest_Importer(
                nonCanonicalScheme: ["u"])));
        await expectParamsError(
            process,
            errorId,
            "Importer.non_canonical_scheme may only be set along with "
            "Importer.importer.importer_id");
        await process.shouldExit(76);
      });
    });
  });

  group("canonicalization", () {
    group("emits a compile failure", () {
      test("for a canonicalize response with an empty URL", () async {
        process.send(compileString("@use 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = 1
        ]));

        var request = await getCanonicalizeRequest(process);
        process.send(InboundMessage()
          ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
            ..id = request.id
            ..url = ""));

        await _expectImportError(
            process, 'The importer must return an absolute URL, was ""');
        await process.close();
      });

      test("for a canonicalize response with a relative URL", () async {
        process.send(compileString("@use 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = 1
        ]));

        var request = await getCanonicalizeRequest(process);
        process.send(InboundMessage()
          ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
            ..id = request.id
            ..url = "relative"));

        await _expectImportError(process,
            'The importer must return an absolute URL, was "relative"');
        await process.close();
      });
    });

    group("includes in CanonicalizeRequest", () {
      var importerId = 5679;
      late OutboundMessage_CanonicalizeRequest request;
      setUp(() async {
        process.send(compileString("@use 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = importerId
        ]));
        request = await getCanonicalizeRequest(process);
      });

      test("a known importerId", () async {
        expect(request.importerId, equals(importerId));
        await process.kill();
      });

      test("the imported URL", () async {
        expect(request.url, equals("other"));
        await process.kill();
      });
    });

    test("errors cause compilation to fail", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = await getCanonicalizeRequest(process);
      process.send(InboundMessage()
        ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
          ..id = request.id
          ..error = "oh no"));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals('oh no'));
      expect(failure.span.text, equals("@use 'other'"));
      expect(failure.stackTrace, equals('- 1:1  root stylesheet\n'));
      await process.close();
    });

    test("null results count as not found", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = await getCanonicalizeRequest(process);
      process.send(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = request.id));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals("Can't find stylesheet to import."));
      expect(failure.span.text, equals("@use 'other'"));
      await process.close();
    });

    group("the containing URL", () {
      test("is unset for a potentially canonical scheme", () async {
        process.send(compileString('@use "u:orange"', importers: [
          InboundMessage_CompileRequest_Importer(importerId: 1)
        ]));

        var request = await getCanonicalizeRequest(process);
        expect(request.hasContainingUrl(), isFalse);
        await process.close();
      });

      group("for a non-canonical scheme", () {
        test("is set to the original URL", () async {
          process.send(compileString('@use "u:orange"',
              importers: [
                InboundMessage_CompileRequest_Importer(
                    importerId: 1, nonCanonicalScheme: ["u"])
              ],
              url: "x:original.scss"));

          var request = await getCanonicalizeRequest(process);
          expect(request.containingUrl, equals("x:original.scss"));
          await process.close();
        });

        test("is unset to the original URL is unset", () async {
          process.send(compileString('@use "u:orange"', importers: [
            InboundMessage_CompileRequest_Importer(
                importerId: 1, nonCanonicalScheme: ["u"])
          ]));

          var request = await getCanonicalizeRequest(process);
          expect(request.hasContainingUrl(), isFalse);
          await process.close();
        });
      });

      group("for a schemeless load", () {
        test("is set to the original URL", () async {
          process.send(compileString('@use "orange"',
              importers: [
                InboundMessage_CompileRequest_Importer(importerId: 1)
              ],
              url: "x:original.scss"));

          var request = await getCanonicalizeRequest(process);
          expect(request.containingUrl, equals("x:original.scss"));
          await process.close();
        });

        test("is unset to the original URL is unset", () async {
          process.send(compileString('@use "u:orange"', importers: [
            InboundMessage_CompileRequest_Importer(importerId: 1)
          ]));

          var request = await getCanonicalizeRequest(process);
          expect(request.hasContainingUrl(), isFalse);
          await process.close();
        });
      });
    });

    test(
        "fails if the importer returns a canonical URL with a non-canonical "
        "scheme", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer(
            importerId: 1, nonCanonicalScheme: ["u"])
      ]));

      var request = await getCanonicalizeRequest(process);
      process.send(InboundMessage(
          canonicalizeResponse: InboundMessage_CanonicalizeResponse(
              id: request.id, url: "u:other")));

      await _expectImportError(
          process, contains('a scheme declared as non-canonical'));
      await process.close();
    });

    test("attempts importers in order", () async {
      process.send(compileString("@use 'other'", importers: [
        for (var i = 0; i < 10; i++)
          InboundMessage_CompileRequest_Importer()..importerId = i
      ]));

      for (var i = 0; i < 10; i++) {
        var request = await getCanonicalizeRequest(process);
        expect(request.importerId, equals(i));
        process.send(InboundMessage()
          ..canonicalizeResponse =
              (InboundMessage_CanonicalizeResponse()..id = request.id));
      }

      await process.close();
    });

    test("tries resolved URL using the original importer first", () async {
      process.send(compileString("@use 'midstream'", importers: [
        for (var i = 0; i < 10; i++)
          InboundMessage_CompileRequest_Importer()..importerId = i
      ]));

      for (var i = 0; i < 5; i++) {
        var request = await getCanonicalizeRequest(process);
        expect(request.url, equals("midstream"));
        expect(request.importerId, equals(i));
        process.send(InboundMessage()
          ..canonicalizeResponse =
              (InboundMessage_CanonicalizeResponse()..id = request.id));
      }

      var canonicalize = await getCanonicalizeRequest(process);
      expect(canonicalize.importerId, equals(5));
      process.send(InboundMessage()
        ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
          ..id = canonicalize.id
          ..url = "custom:foo/bar"));

      var import = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = import.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "@use 'upstream'")));

      canonicalize = await getCanonicalizeRequest(process);
      expect(canonicalize.importerId, equals(5));
      expect(canonicalize.url, equals("custom:foo/upstream"));

      await process.kill();
    });
  });

  group("importing", () {
    group("emits a compile failure", () {
      test("for an import result with a relative sourceMapUrl", () async {
        process.send(compileString("@use 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = 1
        ]));
        await _canonicalize(process);

        var import = await getImportRequest(process);
        process.send(InboundMessage()
          ..importResponse = (InboundMessage_ImportResponse()
            ..id = import.id
            ..success = (InboundMessage_ImportResponse_ImportSuccess()
              ..sourceMapUrl = "relative")));

        await _expectImportError(process,
            'The importer must return an absolute URL, was "relative"');
        await process.close();
      });
    });

    group("includes in ImportRequest", () {
      var importerId = 5678;
      late OutboundMessage_ImportRequest request;
      setUp(() async {
        process.send(compileString("@use 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = importerId
        ]));

        var canonicalize = await getCanonicalizeRequest(process);
        process.send(InboundMessage()
          ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
            ..id = canonicalize.id
            ..url = "custom:foo"));

        request = await getImportRequest(process);
      });

      test("a known importerId", () async {
        expect(request.importerId, equals(importerId));
        await process.kill();
      });

      test("the canonical URL", () async {
        expect(request.url, equals("custom:foo"));
        await process.kill();
      });
    });

    test("null results count as not found", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var canonicalizeRequest = await getCanonicalizeRequest(process);
      process.send(InboundMessage()
        ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
          ..id = canonicalizeRequest.id
          ..url = "o:other"));

      var importRequest = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse =
            (InboundMessage_ImportResponse()..id = importRequest.id));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals("Can't find stylesheet to import."));
      expect(failure.span.text, equals("@use 'other'"));
      await process.close();
    });

    test("errors cause compilation to fail", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..error = "oh no"));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals('oh no'));
      expect(failure.span.text, equals("@use 'other'"));
      expect(failure.stackTrace, equals('- 1:1  root stylesheet\n'));
      await process.close();
    });

    test("can return an SCSS file", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: 1px + 2px}")));

      await expectSuccess(process, "a { b: 3px; }");
      await process.close();
    });

    test("can return an indented syntax file", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a\n  b: 1px + 2px"
            ..syntax = Syntax.INDENTED)));

      await expectSuccess(process, "a { b: 3px; }");
      await process.close();
    });

    test("can return a plain CSS file", () async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: c}"
            ..syntax = Syntax.CSS)));

      await expectSuccess(process, "a { b: c; }");
      await process.close();
    });

    test("uses a data: URL rather than an empty source map URL", () async {
      process.send(compileString("@use 'other'", sourceMap: true, importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: c}"
            ..sourceMapUrl = "")));

      await expectSuccess(process, "a { b: c; }", sourceMap: (String map) {
        var mapping = source_maps.parse(map) as source_maps.SingleMapping;
        expect(mapping.urls, [startsWith("data:")]);
      });
      await process.close();
    });

    test("uses a non-empty source map URL", () async {
      process.send(compileString("@use 'other'", sourceMap: true, importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: c}"
            ..sourceMapUrl = "file:///asdf")));

      await expectSuccess(process, "a { b: c; }", sourceMap: (String map) {
        var mapping = source_maps.parse(map) as source_maps.SingleMapping;
        expect(mapping.urls, equals(["file:///asdf"]));
      });
      await process.close();
    });
  });

  test("handles an importer for a string compile request", () async {
    process.send(compileString("@use 'other'",
        importer: InboundMessage_CompileRequest_Importer()..importerId = 1));
    await _canonicalize(process);

    var request = await getImportRequest(process);
    process.send(InboundMessage()
      ..importResponse = (InboundMessage_ImportResponse()
        ..id = request.id
        ..success = (InboundMessage_ImportResponse_ImportSuccess()
          ..contents = "a {b: 1px + 2px}")));

    await expectSuccess(process, "a { b: 3px; }");
    await process.close();
  });

  group("load paths", () {
    test("are used to load imports", () async {
      await d.dir("dir", [d.file("other.scss", "a {b: c}")]).create();

      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..path = d.path("dir")
      ]));

      await expectSuccess(process, "a { b: c; }");
      await process.close();
    });

    test("are accessed in order", () async {
      for (var i = 0; i < 3; i++) {
        await d.dir("dir$i", [d.file("other$i.scss", "a {b: $i}")]).create();
      }

      process.send(compileString("@use 'other2'", importers: [
        for (var i = 0; i < 3; i++)
          InboundMessage_CompileRequest_Importer()..path = d.path("dir$i")
      ]));

      await expectSuccess(process, "a { b: 2; }");
      await process.close();
    });

    test("take precedence over later importers", () async {
      await d.dir("dir", [d.file("other.scss", "a {b: c}")]).create();

      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..path = d.path("dir"),
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      await expectSuccess(process, "a { b: c; }");
      await process.close();
    });

    test("yield precedence to earlier importers", () async {
      await d.dir("dir", [d.file("other.scss", "a {b: c}")]).create();

      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1,
        InboundMessage_CompileRequest_Importer()..path = d.path("dir")
      ]));
      await _canonicalize(process);

      var request = await getImportRequest(process);
      process.send(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "x {y: z}")));

      await expectSuccess(process, "x { y: z; }");
      await process.close();
    });
  });

  group("fails compilation for an invalid scheme:", () {
    test("empty", () async {
      process.send(compileString("a {b: c}", importers: [
        InboundMessage_CompileRequest_Importer(
            importerId: 1, nonCanonicalScheme: [""])
      ]));

      var failure = await getCompileFailure(process);
      expect(failure.message,
          equals('"" isn\'t a valid URL scheme (for example "file").'));
      await process.close();
    });

    test("uppercase", () async {
      process.send(compileString("a {b: c}", importers: [
        InboundMessage_CompileRequest_Importer(
            importerId: 1, nonCanonicalScheme: ["U"])
      ]));

      var failure = await getCompileFailure(process);
      expect(failure.message,
          equals('"U" isn\'t a valid URL scheme (for example "file").'));
      await process.close();
    });

    test("colon", () async {
      process.send(compileString("a {b: c}", importers: [
        InboundMessage_CompileRequest_Importer(
            importerId: 1, nonCanonicalScheme: ["u:"])
      ]));

      var failure = await getCompileFailure(process);
      expect(failure.message,
          equals('"u:" isn\'t a valid URL scheme (for example "file").'));
      await process.close();
    });
  });
}

/// Handles a `CanonicalizeRequest` and returns a response with a generic
/// canonical URL.
///
/// This is used when testing import requests, to avoid duplicating a bunch of
/// generic code for canonicalization. It shouldn't be used for testing
/// canonicalization itself.
Future<void> _canonicalize(EmbeddedProcess process) async {
  var request = await getCanonicalizeRequest(process);
  process.send(InboundMessage()
    ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
      ..id = request.id
      ..url = "custom:other"));
}

/// Asserts that [process] emits a [CompileFailure] result with the given
/// [message] on its protobuf stream and causes the compilation to fail.
Future<void> _expectImportError(EmbeddedProcess process, Object message) async {
  var failure = await getCompileFailure(process);
  expect(failure.message, equals(message));
  expect(failure.span.text, equals("@use 'other'"));
}
