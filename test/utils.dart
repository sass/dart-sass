// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:sass_embedded/src/embedded_sass.pb.dart';
import 'package:sass_embedded/src/utils.dart';

import 'embedded_process.dart';

/// Returns a [InboundMessage] that compiles the given plain CSS
/// string.
InboundMessage compileString(String css,
    {int? id,
    bool? alertColor,
    bool? alertAscii,
    Syntax? syntax,
    OutputStyle? style,
    String? url,
    bool? sourceMap,
    Iterable<InboundMessage_CompileRequest_Importer>? importers,
    InboundMessage_CompileRequest_Importer? importer,
    Iterable<String>? functions}) {
  var input = InboundMessage_CompileRequest_StringInput()..source = css;
  if (syntax != null) input.syntax = syntax;
  if (url != null) input.url = url;
  if (importer != null) input.importer = importer;

  var request = InboundMessage_CompileRequest()..string = input;
  if (id != null) request.id = id;
  if (importers != null) request.importers.addAll(importers);
  if (style != null) request.style = style;
  if (sourceMap != null) request.sourceMap = sourceMap;
  if (functions != null) request.globalFunctions.addAll(functions);
  if (alertColor != null) request.alertColor = alertColor;
  if (alertAscii != null) request.alertAscii = alertAscii;

  return InboundMessage()..compileRequest = request;
}

/// Asserts that [process] emits a [ProtocolError] parse error with the given
/// [message] on its protobuf stream and prints a notice on stderr.
Future<void> expectParseError(EmbeddedProcess process, Object message) async {
  await expectLater(process.outbound,
      emits(isProtocolError(errorId, ProtocolErrorType.PARSE, message)));

  var stderrPrefix = "Host caused parse error: ";
  await expectLater(
      process.stderr,
      message is String
          ? emitsInOrder("$stderrPrefix$message".split("\n"))
          : emits(startsWith(stderrPrefix)));
}

/// Asserts that [process] emits a [ProtocolError] params error with the given
/// [message] on its protobuf stream and prints a notice on stderr.
Future<void> expectParamsError(
    EmbeddedProcess process, int id, Object message) async {
  await expectLater(process.outbound,
      emits(isProtocolError(id, ProtocolErrorType.PARAMS, message)));

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

/// Asserts that [message] is an [OutboundMessage] with a
/// `CanonicalizeRequest` and returns it.
OutboundMessage_CanonicalizeRequest getCanonicalizeRequest(Object? value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasCanonicalizeRequest(), isTrue,
      reason: "Expected $message to have a CanonicalizeRequest");
  return message.canonicalizeRequest;
}

/// Asserts that [message] is an [OutboundMessage] with a `ImportRequest` and
/// returns it.
OutboundMessage_ImportRequest getImportRequest(Object? value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasImportRequest(), isTrue,
      reason: "Expected $message to have a ImportRequest");
  return message.importRequest;
}

/// Asserts that [message] is an [OutboundMessage] with a `FileImportRequest`
/// and returns it.
OutboundMessage_FileImportRequest getFileImportRequest(Object? value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasFileImportRequest(), isTrue,
      reason: "Expected $message to have a FileImportRequest");
  return message.fileImportRequest;
}

/// Asserts that [message] is an [OutboundMessage] with a
/// `FunctionCallRequest` and returns it.
OutboundMessage_FunctionCallRequest getFunctionCallRequest(Object? value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasFunctionCallRequest(), isTrue,
      reason: "Expected $message to have a FunctionCallRequest");
  return message.functionCallRequest;
}

/// Asserts that [message] is an [OutboundMessage] with a
/// `CompileResponse.Failure` and returns it.
OutboundMessage_CompileResponse_CompileFailure getCompileFailure(
    Object? value) {
  var response = getCompileResponse(value);
  expect(response.hasFailure(), isTrue,
      reason: "Expected $response to be a failure");
  return response.failure;
}

/// Asserts that [message] is an [OutboundMessage] with a
/// `CompileResponse.Success` and returns it.
OutboundMessage_CompileResponse_CompileSuccess getCompileSuccess(
    Object? value) {
  var response = getCompileResponse(value);
  expect(response.hasSuccess(), isTrue,
      reason: "Expected $response to be a success");
  return response.success;
}

/// Asserts that [message] is an [OutboundMessage] with a `CompileResponse` and
/// returns it.
OutboundMessage_CompileResponse getCompileResponse(Object? value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasCompileResponse(), isTrue,
      reason: "Expected $message to have a CompileResponse");
  return message.compileResponse;
}

/// Asserts that [message] is an [OutboundMessage] with a `LogEvent` and
/// returns it.
OutboundMessage_LogEvent getLogEvent(Object? value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasLogEvent(), isTrue,
      reason: "Expected $message to have a LogEvent");
  return message.logEvent;
}

/// Asserts that an [OutboundMessage] is a `CompileResponse` with CSS that
/// matches [css], with a source map that matches [sourceMap] (if passed).
///
/// If [css] is a [String], this automatically wraps it in
/// [equalsIgnoringWhitespace].
///
/// If [sourceMap] is a function, `response.success.sourceMap` is passed to it.
/// Otherwise, it's treated as a matcher for `response.success.sourceMap`.
Matcher isSuccess(Object css, {Object? sourceMap}) => predicate((value) {
      var success = getCompileSuccess(value);
      expect(success.css, css is String ? equalsIgnoringWhitespace(css) : css);
      if (sourceMap is void Function(String)) {
        sourceMap(success.sourceMap);
      } else if (sourceMap != null) {
        expect(success.sourceMap, sourceMap);
      }
      return true;
    });

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
