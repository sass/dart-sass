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
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = getCanonicalizeRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = request.id + 1));

      await expectParamsError(
          process,
          errorId,
          "Response ID ${request.id + 1} doesn't match any outstanding "
          "requests.");
      await process.kill();
    });

    test("for a response that doesn't match the request type", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = getCanonicalizeRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()..id = request.id));

      await expectParamsError(
          process,
          errorId,
          "Request ID ${request.id} doesn't match response type "
          "InboundMessage_ImportResponse.");
      await process.kill();
    });

    test("for an unset importer", () async {
      process.inbound.add(compileString("a {b: c}",
          importers: [InboundMessage_CompileRequest_Importer()]));
      await expectParamsError(
          process, 0, "Missing mandatory field Importer.importer");
      await process.kill();
    });
  });

  group("canonicalization", () {
    group("emits a compile failure", () {
      test("for a canonicalize response with an empty URL", () async {
        process.inbound.add(compileString("@import 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = 1
        ]));

        var request = getCanonicalizeRequest(await process.outbound.next);
        process.inbound.add(InboundMessage()
          ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
            ..id = request.id
            ..url = ""));

        await _expectImportError(
            process, 'The importer must return an absolute URL, was ""');
        await process.kill();
      });

      test("for a canonicalize response with a relative URL", () async {
        process.inbound.add(compileString("@import 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = 1
        ]));

        var request = getCanonicalizeRequest(await process.outbound.next);
        process.inbound.add(InboundMessage()
          ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
            ..id = request.id
            ..url = "relative"));

        await _expectImportError(process,
            'The importer must return an absolute URL, was "relative"');
        await process.kill();
      });
    });

    group("includes in CanonicalizeRequest", () {
      var compilationId = 1234;
      var importerId = 5679;
      late OutboundMessage_CanonicalizeRequest request;
      setUp(() async {
        process.inbound.add(compileString("@import 'other'",
            id: compilationId,
            importers: [
              InboundMessage_CompileRequest_Importer()..importerId = importerId
            ]));
        request = getCanonicalizeRequest(await process.outbound.next);
      });

      test("the same compilationId as the compilation", () async {
        expect(request.compilationId, equals(compilationId));
        await process.kill();
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
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = getCanonicalizeRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
          ..id = request.id
          ..error = "oh no"));

      var failure = getCompileFailure(await process.outbound.next);
      expect(failure.message, equals('oh no'));
      expect(failure.span.text, equals("'other'"));
      expect(failure.stackTrace, equals('- 1:9  root stylesheet\n'));
      await process.kill();
    });

    test("null results count as not found", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var request = getCanonicalizeRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = request.id));

      var failure = getCompileFailure(await process.outbound.next);
      expect(failure.message, equals("Can't find stylesheet to import."));
      expect(failure.span.text, equals("'other'"));
      await process.kill();
    });

    test("attempts importers in order", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        for (var i = 0; i < 10; i++)
          InboundMessage_CompileRequest_Importer()..importerId = i
      ]));

      for (var i = 0; i < 10; i++) {
        var request = getCanonicalizeRequest(await process.outbound.next);
        expect(request.importerId, equals(i));
        process.inbound.add(InboundMessage()
          ..canonicalizeResponse =
              (InboundMessage_CanonicalizeResponse()..id = request.id));
      }

      await process.kill();
    });

    test("tries resolved URL using the original importer first", () async {
      process.inbound.add(compileString("@import 'midstream'", importers: [
        for (var i = 0; i < 10; i++)
          InboundMessage_CompileRequest_Importer()..importerId = i
      ]));

      for (var i = 0; i < 5; i++) {
        var request = getCanonicalizeRequest(await process.outbound.next);
        expect(request.url, equals("midstream"));
        expect(request.importerId, equals(i));
        process.inbound.add(InboundMessage()
          ..canonicalizeResponse =
              (InboundMessage_CanonicalizeResponse()..id = request.id));
      }

      var canonicalize = getCanonicalizeRequest(await process.outbound.next);
      expect(canonicalize.importerId, equals(5));
      process.inbound.add(InboundMessage()
        ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
          ..id = canonicalize.id
          ..url = "custom:foo/bar"));

      var import = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = import.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "@import 'upstream'")));

      canonicalize = getCanonicalizeRequest(await process.outbound.next);
      expect(canonicalize.importerId, equals(5));
      expect(canonicalize.url, equals("custom:foo/upstream"));

      await process.kill();
    });
  });

  group("importing", () {
    group("emits a compile failure", () {
      test("for an import result with a relative sourceMapUrl", () async {
        process.inbound.add(compileString("@import 'other'", importers: [
          InboundMessage_CompileRequest_Importer()..importerId = 1
        ]));
        await _canonicalize(process);

        var import = getImportRequest(await process.outbound.next);
        process.inbound.add(InboundMessage()
          ..importResponse = (InboundMessage_ImportResponse()
            ..id = import.id
            ..success = (InboundMessage_ImportResponse_ImportSuccess()
              ..sourceMapUrl = "relative")));

        await _expectImportError(process,
            'The importer must return an absolute URL, was "relative"');
        await process.kill();
      });
    });

    group("includes in ImportRequest", () {
      var compilationId = 1234;
      var importerId = 5678;
      late OutboundMessage_ImportRequest request;
      setUp(() async {
        process.inbound.add(compileString("@import 'other'",
            id: compilationId,
            importers: [
              InboundMessage_CompileRequest_Importer()..importerId = importerId
            ]));

        var canonicalize = getCanonicalizeRequest(await process.outbound.next);
        process.inbound.add(InboundMessage()
          ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
            ..id = canonicalize.id
            ..url = "custom:foo"));

        request = getImportRequest(await process.outbound.next);
      });

      test("the same compilationId as the compilation", () async {
        expect(request.compilationId, equals(compilationId));
        await process.kill();
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
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      var canonicalizeRequest =
          getCanonicalizeRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
          ..id = canonicalizeRequest.id
          ..url = "o:other"));

      var importRequest = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse =
            (InboundMessage_ImportResponse()..id = importRequest.id));

      var failure = getCompileFailure(await process.outbound.next);
      expect(failure.message, equals("Can't find stylesheet to import."));
      expect(failure.span.text, equals("'other'"));
      await process.kill();
    });

    test("errors cause compilation to fail", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..error = "oh no"));

      var failure = getCompileFailure(await process.outbound.next);
      expect(failure.message, equals('oh no'));
      expect(failure.span.text, equals("'other'"));
      expect(failure.stackTrace, equals('- 1:9  root stylesheet\n'));
      await process.kill();
    });

    test("can return an SCSS file", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: 1px + 2px}")));

      await expectLater(process.outbound, emits(isSuccess("a { b: 3px; }")));
      await process.kill();
    });

    test("can return an indented syntax file", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a\n  b: 1px + 2px"
            ..syntax = Syntax.INDENTED)));

      await expectLater(process.outbound, emits(isSuccess("a { b: 3px; }")));
      await process.kill();
    });

    test("can return a plain CSS file", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: c}"
            ..syntax = Syntax.CSS)));

      await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
      await process.kill();
    });

    test("uses a data: URL rather than an empty source map URL", () async {
      process.inbound.add(compileString("@import 'other'",
          sourceMap: true,
          importers: [
            InboundMessage_CompileRequest_Importer()..importerId = 1
          ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: c}"
            ..sourceMapUrl = "")));

      await expectLater(
          process.outbound,
          emits(isSuccess("a { b: c; }", sourceMap: (String map) {
            var mapping = source_maps.parse(map) as source_maps.SingleMapping;
            expect(mapping.urls, [startsWith("data:")]);
          })));
      await process.kill();
    });

    test("uses a non-empty source map URL", () async {
      process.inbound.add(compileString("@import 'other'",
          sourceMap: true,
          importers: [
            InboundMessage_CompileRequest_Importer()..importerId = 1
          ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "a {b: c}"
            ..sourceMapUrl = "file:///asdf")));

      await expectLater(
          process.outbound,
          emits(isSuccess("a { b: c; }", sourceMap: (String map) {
            var mapping = source_maps.parse(map) as source_maps.SingleMapping;
            expect(mapping.urls, equals(["file:///asdf"]));
          })));
      await process.kill();
    });
  });

  test("handles an importer for a string compile request", () async {
    process.inbound.add(compileString("@import 'other'",
        importer: InboundMessage_CompileRequest_Importer()..importerId = 1));
    await _canonicalize(process);

    var request = getImportRequest(await process.outbound.next);
    process.inbound.add(InboundMessage()
      ..importResponse = (InboundMessage_ImportResponse()
        ..id = request.id
        ..success = (InboundMessage_ImportResponse_ImportSuccess()
          ..contents = "a {b: 1px + 2px}")));

    await expectLater(process.outbound, emits(isSuccess("a { b: 3px; }")));
    await process.kill();
  });

  group("load paths", () {
    test("are used to load imports", () async {
      await d.dir("dir", [d.file("other.scss", "a {b: c}")]).create();

      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..path = d.path("dir")
      ]));

      await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
      await process.kill();
    });

    test("are accessed in order", () async {
      for (var i = 0; i < 3; i++) {
        await d.dir("dir$i", [d.file("other$i.scss", "a {b: $i}")]).create();
      }

      process.inbound.add(compileString("@import 'other2'", importers: [
        for (var i = 0; i < 3; i++)
          InboundMessage_CompileRequest_Importer()..path = d.path("dir$i")
      ]));

      await expectLater(process.outbound, emits(isSuccess("a { b: 2; }")));
      await process.kill();
    });

    test("take precedence over later importers", () async {
      await d.dir("dir", [d.file("other.scss", "a {b: c}")]).create();

      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..path = d.path("dir"),
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));

      await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
      await process.kill();
    });

    test("yield precedence to earlier importers", () async {
      await d.dir("dir", [d.file("other.scss", "a {b: c}")]).create();

      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1,
        InboundMessage_CompileRequest_Importer()..path = d.path("dir")
      ]));
      await _canonicalize(process);

      var request = getImportRequest(await process.outbound.next);
      process.inbound.add(InboundMessage()
        ..importResponse = (InboundMessage_ImportResponse()
          ..id = request.id
          ..success = (InboundMessage_ImportResponse_ImportSuccess()
            ..contents = "x {y: z}")));

      await expectLater(process.outbound, emits(isSuccess("x { y: z; }")));
      await process.kill();
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
  var request = getCanonicalizeRequest(await process.outbound.next);
  process.inbound.add(InboundMessage()
    ..canonicalizeResponse = (InboundMessage_CanonicalizeResponse()
      ..id = request.id
      ..url = "custom:other"));
}

/// Asserts that [process] emits a [CompileFailure] result with the given
/// [message] on its protobuf stream and causes the compilation to fail.
Future<void> _expectImportError(EmbeddedProcess process, Object message) async {
  var failure = getCompileFailure(await process.outbound.next);
  expect(failure.message, equals(message));
  expect(failure.span.text, equals("'other'"));
}
