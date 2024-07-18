// Copyright 2021 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:path/path.dart' as p;
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
    late OutboundMessage_FileImportRequest request;

    setUp(() async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..fileImporterId = 1
      ]));

      request = await getFileImportRequest(process);
    });

    test("for a response without a corresponding request ID", () async {
      process.send(InboundMessage()
        ..fileImportResponse =
            (InboundMessage_FileImportResponse()..id = request.id + 1));

      await expectParamsError(
          process,
          errorId,
          "Response ID ${request.id + 1} doesn't match any outstanding "
          "requests in compilation $defaultCompilationId.");
      await process.shouldExit(76);
    });

    test("for a response that doesn't match the request type", () async {
      process.send(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = request.id));

      await expectParamsError(
          process,
          errorId,
          "Request ID ${request.id} doesn't match response type "
          "InboundMessage_CanonicalizeResponse in compilation "
          "$defaultCompilationId.");
      await process.shouldExit(76);
    });
  });

  group("emits a compile failure", () {
    late OutboundMessage_FileImportRequest request;

    setUp(() async {
      process.send(compileString("@use 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..fileImporterId = 1
      ]));

      request = await getFileImportRequest(process);
    });

    group("for a FileImportResponse with a URL", () {
      test("that's empty", () async {
        process.send(InboundMessage()
          ..fileImportResponse = (InboundMessage_FileImportResponse()
            ..id = request.id
            ..fileUrl = ""));

        await _expectUseError(
            process, 'The file importer must return an absolute URL, was ""');
        await process.close();
      });

      test("that's relative", () async {
        process.send(InboundMessage()
          ..fileImportResponse = (InboundMessage_FileImportResponse()
            ..id = request.id
            ..fileUrl = "foo"));

        await _expectUseError(process,
            'The file importer must return an absolute URL, was "foo"');
        await process.close();
      });

      test("that's not file:", () async {
        process.send(InboundMessage()
          ..fileImportResponse = (InboundMessage_FileImportResponse()
            ..id = request.id
            ..fileUrl = "other:foo"));

        await _expectUseError(process,
            'The file importer must return a file: URL, was "other:foo"');
        await process.close();
      });
    });
  });

  group("includes in FileImportRequest", () {
    var compilationId = 1234;
    var importerId = 5679;
    late OutboundMessage_FileImportRequest request;
    setUp(() async {
      process.send(compileString("@use 'other'", id: compilationId, importers: [
        InboundMessage_CompileRequest_Importer()..fileImporterId = importerId
      ]));
      request = await getFileImportRequest(process);
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
      expect(request.fromImport, isFalse);
      await process.kill();
    });
  });

  test("errors cause compilation to fail", () async {
    process.send(compileString("@use 'other'", importers: [
      InboundMessage_CompileRequest_Importer()..fileImporterId = 1
    ]));

    var request = await getFileImportRequest(process);
    process.send(InboundMessage()
      ..fileImportResponse = (InboundMessage_FileImportResponse()
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
      InboundMessage_CompileRequest_Importer()..fileImporterId = 1
    ]));

    var request = await getFileImportRequest(process);
    process.send(InboundMessage()
      ..fileImportResponse =
          (InboundMessage_FileImportResponse()..id = request.id));

    var failure = await getCompileFailure(process);
    expect(failure.message, equals("Can't find stylesheet to import."));
    expect(failure.span.text, equals("@use 'other'"));
    await process.close();
  });

  group("attempts importers in order", () {
    test("with multiple file importers", () async {
      process.send(compileString("@use 'other'", importers: [
        for (var i = 0; i < 10; i++)
          InboundMessage_CompileRequest_Importer()..fileImporterId = i
      ]));

      for (var i = 0; i < 10; i++) {
        var request = await getFileImportRequest(process);
        expect(request.importerId, equals(i));
        process.send(InboundMessage()
          ..fileImportResponse =
              (InboundMessage_FileImportResponse()..id = request.id));
      }

      await process.kill();
    });

    test("with a mixture of file and normal importers", () async {
      process.send(compileString("@use 'other'", importers: [
        for (var i = 0; i < 10; i++)
          if (i % 2 == 0)
            InboundMessage_CompileRequest_Importer()..fileImporterId = i
          else
            InboundMessage_CompileRequest_Importer()..importerId = i
      ]));

      for (var i = 0; i < 10; i++) {
        if (i % 2 == 0) {
          var request = await getFileImportRequest(process);
          expect(request.importerId, equals(i));
          process.send(InboundMessage()
            ..fileImportResponse =
                (InboundMessage_FileImportResponse()..id = request.id));
        } else {
          var request = await getCanonicalizeRequest(process);
          expect(request.importerId, equals(i));
          process.send(InboundMessage()
            ..canonicalizeResponse =
                (InboundMessage_CanonicalizeResponse()..id = request.id));
        }
      }

      await process.kill();
    });
  });

  test("tries resolved URL as a relative path first", () async {
    await d.file("upstream.scss", "a {b: c}").create();
    await d.file("midstream.scss", "@use 'upstream';").create();

    process.send(compileString("@use 'midstream'", importers: [
      for (var i = 0; i < 10; i++)
        InboundMessage_CompileRequest_Importer()..fileImporterId = i
    ]));

    for (var i = 0; i < 5; i++) {
      var request = await getFileImportRequest(process);
      expect(request.url, equals("midstream"));
      expect(request.importerId, equals(i));
      process.send(InboundMessage()
        ..fileImportResponse =
            (InboundMessage_FileImportResponse()..id = request.id));
    }

    var request = await getFileImportRequest(process);
    expect(request.importerId, equals(5));
    process.send(InboundMessage()
      ..fileImportResponse = (InboundMessage_FileImportResponse()
        ..id = request.id
        ..fileUrl = p.toUri(d.path("midstream")).toString()));

    await expectSuccess(process, "a { b: c; }");
    await process.close();
  });

  group("handles an importer for a string compile request", () {
    setUp(() async {
      await d.file("other.scss", "a {b: c}").create();
    });

    test("without a base URL", () async {
      process.send(compileString("@use 'other'",
          importer: InboundMessage_CompileRequest_Importer()
            ..fileImporterId = 1));

      var request = await getFileImportRequest(process);
      expect(request.url, equals("other"));

      process.send(InboundMessage()
        ..fileImportResponse = (InboundMessage_FileImportResponse()
          ..id = request.id
          ..fileUrl = p.toUri(d.path("other")).toString()));

      await expectSuccess(process, "a { b: c; }");
      await process.close();
    });

    test("with a base URL", () async {
      process.send(compileString("@use 'other'",
          url: p.toUri(d.path("input")).toString(),
          importer: InboundMessage_CompileRequest_Importer()
            ..fileImporterId = 1));

      await expectSuccess(process, "a { b: c; }");
      await process.close();
    });
  });
}

/// Asserts that [process] emits a [CompileFailure] result with the given
/// [message] on its protobuf stream and causes the compilation to fail.
Future<void> _expectUseError(EmbeddedProcess process, Object message) async {
  var failure = await getCompileFailure(process);
  expect(failure.message, equals(message));
  expect(failure.span.text, equals("@use 'other'"));
}
