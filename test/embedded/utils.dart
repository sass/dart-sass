// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:sass/src/deprecation.dart';
import 'package:sass/src/embedded/embedded_sass.pb.dart';
import 'package:sass/src/embedded/utils.dart';
import 'package:sass/src/util/nullable.dart';

import 'embedded_process.dart';

/// An arbitrary compilation ID to use for tests where the specific ID doesn't
/// matter.
const defaultCompilationId = 4321;

/// Returns a (compilation ID, [InboundMessage]) pair that compiles the given
/// plain CSS string.
InboundMessage compileString(String css,
    {int? id,
    bool? alertColor,
    bool? alertAscii,
    Syntax? syntax,
    OutputStyle? style,
    String? url,
    bool? sourceMap,
    bool? sourceMapIncludeSources,
    Iterable<InboundMessage_CompileRequest_Importer>? importers,
    InboundMessage_CompileRequest_Importer? importer,
    Iterable<String>? functions,
    Iterable<String>? fatalDeprecations,
    Iterable<String>? futureDeprecations,
    Iterable<String>? silenceDeprecations}) {
  var input = InboundMessage_CompileRequest_StringInput()..source = css;
  if (syntax != null) input.syntax = syntax;
  if (url != null) input.url = url;
  if (importer != null) input.importer = importer;

  var request = InboundMessage_CompileRequest()..string = input;
  if (importers != null) request.importers.addAll(importers);
  if (style != null) request.style = style;
  if (sourceMap != null) request.sourceMap = sourceMap;
  if (sourceMapIncludeSources != null) {
    request.sourceMapIncludeSources = sourceMapIncludeSources;
  }
  if (functions != null) request.globalFunctions.addAll(functions);
  if (alertColor != null) request.alertColor = alertColor;
  if (alertAscii != null) request.alertAscii = alertAscii;
  fatalDeprecations.andThen(request.fatalDeprecation.addAll);
  futureDeprecations.andThen(request.futureDeprecation.addAll);
  silenceDeprecations.andThen(request.silenceDeprecation.addAll);
  return InboundMessage()..compileRequest = request;
}

/// Asserts that [process] emits a [ProtocolError] parse error with the given
/// [message] on its protobuf stream and prints a notice on stderr.
Future<void> expectParseError(EmbeddedProcess process, Object message,
    {int compilationId = defaultCompilationId}) async {
  var (actualCompilationId, actualMessage) = await process.outbound.next;
  expect(actualCompilationId, equals(compilationId));
  expect(actualMessage,
      isProtocolError(errorId, ProtocolErrorType.PARSE, message));

  var stderrPrefix = "Host caused parse error: ";
  await expectLater(
      process.stderr,
      message is String
          ? emitsInOrder("$stderrPrefix$message".split("\n"))
          : emits(startsWith(stderrPrefix)));
}

/// Asserts that [process] emits a [ProtocolError] params error with the given
/// [message] on its protobuf stream and prints a notice on stderr.
Future<void> expectParamsError(EmbeddedProcess process, int id, Object message,
    {int compilationId = defaultCompilationId}) async {
  var (actualCompilationId, actualMessage) = await process.outbound.next;
  expect(actualCompilationId, equals(compilationId));
  expect(actualMessage, isProtocolError(id, ProtocolErrorType.PARAMS, message));

  var stderrPrefix = "Host caused params error"
      "${id == errorId ? '' : " with request $id"}: ";
  await expectLater(
      process.stderr,
      message is String
          ? emitsInOrder("$stderrPrefix$message".split("\n"))
          : emits(startsWith(stderrPrefix)));
}

/// Asserts that an [OutboundMessage] is a [ProtocolError] with the given [id],
/// [type], and optionally [message].
Matcher isProtocolError(int id, ProtocolErrorType type, [Object? message]) =>
    predicate((value) {
      expect(value, isA<OutboundMessage>());
      var outboundMessage = value as OutboundMessage;
      expect(outboundMessage.hasError(), isTrue,
          reason: "Expected $outboundMessage to be a ProtocolError");
      expect(outboundMessage.error.id, equals(id));
      expect(outboundMessage.error.type, equals(type));
      if (message != null) expect(outboundMessage.error.message, message);
      return true;
    });

/// Asserts [process] emits a `CanonicalizeRequest` with the default compilation
/// ID and returns it.
Future<OutboundMessage_CanonicalizeRequest> getCanonicalizeRequest(
    EmbeddedProcess process) async {
  var message = await process.receive();
  expect(message.hasCanonicalizeRequest(), isTrue,
      reason: "Expected $message to have a CanonicalizeRequest");
  return message.canonicalizeRequest;
}

/// Asserts [process] emits an `ImportRequest` with the default compilation ID
/// and returns it.
Future<OutboundMessage_ImportRequest> getImportRequest(
    EmbeddedProcess process) async {
  var message = await process.receive();
  expect(message.hasImportRequest(), isTrue,
      reason: "Expected $message to have a ImportRequest");
  return message.importRequest;
}

/// Asserts that [process] emits a `FileImportRequest` with the default
/// compilation ID and returns it.
Future<OutboundMessage_FileImportRequest> getFileImportRequest(
    EmbeddedProcess process) async {
  var message = await process.receive();
  expect(message.hasFileImportRequest(), isTrue,
      reason: "Expected $message to have a FileImportRequest");
  return message.fileImportRequest;
}

/// Asserts that [process] emits a `FunctionCallRequest` with the default
/// compilation ID and returns it.
Future<OutboundMessage_FunctionCallRequest> getFunctionCallRequest(
    EmbeddedProcess process) async {
  var message = await process.receive();
  expect(message.hasFunctionCallRequest(), isTrue,
      reason: "Expected $message to have a FunctionCallRequest");
  return message.functionCallRequest;
}

/// Asserts that [process] emits a with the default compilation ID
/// `CompileResponse.Failure` and returns it.
Future<OutboundMessage_CompileResponse_CompileFailure> getCompileFailure(
    EmbeddedProcess process) async {
  var response = await getCompileResponse(process);
  expect(response.hasFailure(), isTrue,
      reason: "Expected $response to be a failure");
  return response.failure;
}

/// Asserts that [process] emits a with the default compilation ID
/// `CompileResponse.Success` and returns it.
Future<OutboundMessage_CompileResponse_CompileSuccess> getCompileSuccess(
    EmbeddedProcess process) async {
  var response = await getCompileResponse(process);
  expect(response.hasSuccess(), isTrue,
      reason: "Expected $response to be a success");
  return response.success;
}

/// Asserts that [process] emits a `CompileResponse` and with the default
/// compilation ID returns it.
Future<OutboundMessage_CompileResponse> getCompileResponse(
    EmbeddedProcess process) async {
  var message = await process.receive();
  expect(message.hasCompileResponse(), isTrue,
      reason: "Expected $message to have a CompileResponse");
  return message.compileResponse;
}

/// Asserts that [process] emits a `LogEvent` and returns with the default
/// compilation ID it.
Future<OutboundMessage_LogEvent> getLogEvent(EmbeddedProcess process) async {
  var message = await process.receive();
  expect(message.hasLogEvent(), isTrue,
      reason: "Expected $message to have a LogEvent");
  return message.logEvent;
}

/// Asserts that [process] emits a deprecation warning of the given type.
Future<void> expectDeprecationMessage(
    EmbeddedProcess process, Deprecation deprecation) async {
  var event = await getLogEvent(process);
  expect(event.type, equals(LogEventType.DEPRECATION_WARNING),
      reason: "Expected a deprecation warning.");
  expect(event.deprecationType, equals('importer-without-url'));
}

/// Asserts that [process] emits a `CompileResponse` with CSS that matches
/// [css], with a source map that matches [sourceMap] (if passed).
///
/// If [css] is a [String], this automatically wraps it in
/// [equalsIgnoringWhitespace].
///
/// If [sourceMap] is a function, `response.success.sourceMap` is passed to it.
/// Otherwise, it's treated as a matcher for `response.success.sourceMap`.
Future<void> expectSuccess(EmbeddedProcess process, Object css,
    {Object? sourceMap}) async {
  var success = await getCompileSuccess(process);
  expect(success.css, css is String ? equalsIgnoringWhitespace(css) : css);
  if (sourceMap is void Function(String)) {
    sourceMap(success.sourceMap);
  } else if (sourceMap != null) {
    expect(success.sourceMap, sourceMap);
  }
}

/// Returns a [SourceSpan_SourceLocation] with the given [offset], [line], and
/// [column].
SourceSpan_SourceLocation location(int offset, int line, int column) =>
    SourceSpan_SourceLocation()
      ..offset = offset
      ..line = line
      ..column = column;

/// Returns a matcher that verifies whether the given value refers to the same
/// path as [expected].
Matcher equalsPath(String expected) => predicate<String>(
    (actual) => p.equals(actual, expected), "equals $expected");
