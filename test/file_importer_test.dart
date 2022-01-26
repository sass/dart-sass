// Copyright 2021 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:sass_embedded/src/embedded_sass.pb.dart';
import 'package:sass_embedded/src/utils.dart';

import 'embedded_process.dart';
import 'utils.dart';

void main() {
  late EmbeddedProcess process;
  setUp(() async {
    process = await EmbeddedProcess.start();
  });

  group("emits a protocol error", () {
    late OutboundMessage_FileImportRequest request;

    setUp(() async {
      process.inbound.add(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..fileImporterId = 1
      ]));

      request = getFileImportRequest(await process.outbound.next);
    });

    test("for a response without a corresponding request ID", () async {
      process.inbound.add(InboundMessage()
        ..fileImportResponse =
            (InboundMessage_FileImportResponse()..id = request.id + 1));

      await expectParamsError(
          process,
          errorId,
          "Response ID ${request.id + 1} doesn't match any outstanding "
          "requests.");
      await process.kill();
    });

    test("for a response that doesn't match the request type", () async {
      process.inbound.add(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = request.id));

      await expectParamsError(
          process,
          errorId,
          "Request ID ${request.id} doesn't match response type "
          "InboundMessage_CanonicalizeResponse.");
      await process.kill();
    });

    group("for a FileImportResponse with a URL", () {
      test("that's empty", () async {
        process.inbound.add(InboundMessage()
          ..fileImportResponse = (InboundMessage_FileImportResponse()
            ..id = request.id
            ..fileUrl = ""));

        await _expectImportParamsError(
            process, 'FileImportResponse.file_url must be absolute, was ""');
        await process.kill();
      });

      test("that's relative", () async {
        process.inbound.add(InboundMessage()
          ..fileImportResponse = (InboundMessage_FileImportResponse()
            ..id = request.id
            ..fileUrl = "foo"));

        await _expectImportParamsError(
            process, 'FileImportResponse.file_url must be absolute, was "foo"');
        await process.kill();
      });

      test("that's not file:", () async {
        process.inbound.add(InboundMessage()
          ..fileImportResponse = (InboundMessage_FileImportResponse()
            ..id = request.id
            ..fileUrl = "other:foo"));

        await _expectImportParamsError(process,
            'FileImportResponse.file_url must be a file: URL, was "other:foo"');
        await process.kill();
      });
    });
  });

  group("includes in FileImportRequest", () {
    var compilationId = 1234;
    var importerId = 5679;
    late OutboundMessage_FileImportRequest request;
    setUp(() async {
      process.inbound.add(
          compileString("@import 'other'", id: compilationId, importers: [
        InboundMessage_CompileRequest_Importer()..fileImporterId = importerId
      ]));
      request = getFileImportRequest(await process.outbound.next);
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

    test("whether the import came from an @import", () async {
      expect(request.fromImport, isTrue);
      await process.kill();
    });
  });

  test("errors cause compilation to fail", () async {
    process.inbound.add(compileString("@import 'other'", importers: [
      InboundMessage_CompileRequest_Importer()..fileImporterId = 1
    ]));

    var request = getFileImportRequest(await process.outbound.next);
    process.inbound.add(InboundMessage()
      ..fileImportResponse = (InboundMessage_FileImportResponse()
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
      InboundMessage_CompileRequest_Importer()..fileImporterId = 1
    ]));

    var request = getFileImportRequest(await process.outbound.next);
    process.inbound.add(InboundMessage()
      ..fileImportResponse =
          (InboundMessage_FileImportResponse()..id = request.id));

    var failure = getCompileFailure(await process.outbound.next);
    expect(failure.message, equals("Can't find stylesheet to import."));
    expect(failure.span.text, equals("'other'"));
    await process.kill();
  });

  group("attempts importers in order", () {
    test("with multiple file importers", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        for (var i = 0; i < 10; i++)
          InboundMessage_CompileRequest_Importer()..fileImporterId = i
      ]));

      for (var i = 0; i < 10; i++) {
        var request = getFileImportRequest(await process.outbound.next);
        expect(request.importerId, equals(i));
        process.inbound.add(InboundMessage()
          ..fileImportResponse =
              (InboundMessage_FileImportResponse()..id = request.id));
      }

      await process.kill();
    });

    test("with a mixture of file and normal importers", () async {
      process.inbound.add(compileString("@import 'other'", importers: [
        for (var i = 0; i < 10; i++)
          if (i % 2 == 0)
            InboundMessage_CompileRequest_Importer()..fileImporterId = i
          else
            InboundMessage_CompileRequest_Importer()..importerId = i
      ]));

      for (var i = 0; i < 10; i++) {
        if (i % 2 == 0) {
          var request = getFileImportRequest(await process.outbound.next);
          expect(request.importerId, equals(i));
          process.inbound.add(InboundMessage()
            ..fileImportResponse =
                (InboundMessage_FileImportResponse()..id = request.id));
        } else {
          var request = getCanonicalizeRequest(await process.outbound.next);
          expect(request.importerId, equals(i));
          process.inbound.add(InboundMessage()
            ..canonicalizeResponse =
                (InboundMessage_CanonicalizeResponse()..id = request.id));
        }
      }

      await process.kill();
    });
  });

  test("tries resolved URL as a relative path first", () async {
    await d.file("upstream.scss", "a {b: c}").create();
    await d.file("midstream.scss", "@import 'upstream';").create();

    process.inbound.add(compileString("@import 'midstream'", importers: [
      for (var i = 0; i < 10; i++)
        InboundMessage_CompileRequest_Importer()..fileImporterId = i
    ]));

    for (var i = 0; i < 5; i++) {
      var request = getFileImportRequest(await process.outbound.next);
      expect(request.url, equals("midstream"));
      expect(request.importerId, equals(i));
      process.inbound.add(InboundMessage()
        ..fileImportResponse =
            (InboundMessage_FileImportResponse()..id = request.id));
    }

    var request = getFileImportRequest(await process.outbound.next);
    expect(request.importerId, equals(5));
    process.inbound.add(InboundMessage()
      ..fileImportResponse = (InboundMessage_FileImportResponse()
        ..id = request.id
        ..fileUrl = p.toUri(d.path("midstream")).toString()));

    await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
    await process.kill();
  });

  group("handles an importer for a string compile request", () {
    setUp(() async {
      await d.file("other.scss", "a {b: c}").create();
    });

    test("without a base URL", () async {
      process.inbound.add(compileString("@import 'other'",
          importer: InboundMessage_CompileRequest_Importer()
            ..fileImporterId = 1));

      var request = getFileImportRequest(await process.outbound.next);
      expect(request.url, equals("other"));

      process.inbound.add(InboundMessage()
        ..fileImportResponse = (InboundMessage_FileImportResponse()
          ..id = request.id
          ..fileUrl = p.toUri(d.path("other")).toString()));

      await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
      await process.kill();
    });

    test("with a base URL", () async {
      process.inbound.add(compileString("@import 'other'",
          url: p.toUri(d.path("input")).toString(),
          importer: InboundMessage_CompileRequest_Importer()
            ..fileImporterId = 1));

      await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
      await process.kill();
    });
  });
}

/// Asserts that [process] emits a [ProtocolError] params error with the given
/// [message] on its protobuf stream and causes the compilation to fail.
Future<void> _expectImportParamsError(
    EmbeddedProcess process, Object message) async {
  await expectLater(process.outbound,
      emits(isProtocolError(errorId, ProtocolErrorType.PARAMS, message)));

  var failure = getCompileFailure(await process.outbound.next);
  expect(failure.message, equals('Protocol error: $message'));
  expect(failure.span.text, equals("'other'"));
}
