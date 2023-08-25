// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:path/path.dart' as p;
import 'package:protobuf/protobuf.dart';
import 'package:sass/sass.dart' as sass;

import 'embedded_sass.pb.dart';
import 'function_registry.dart';
import 'host_callable.dart';
import 'importer/file.dart';
import 'importer/host.dart';
import 'logger.dart';
import 'util/proto_extensions.dart';
import 'utils.dart';

/// The request ID used for all outbound requests.
///
/// Since the dispatcher runs a single-threaded compilation, it will only ever
/// have one active request at a time, so there's no need to vary the ID.
final _outboundRequestId = 0;

/// A class that dispatches messages to and from the host for a single
/// compilation.
final class Dispatcher {
  /// The mailbox for receiving messages from the host.
  final Mailbox _mailbox;

  /// The sink for sending messages to the host.
  final StreamSink<Uint8List> _sink;

  /// The compilation ID for which this dispatcher is running.
  ///
  /// This is used in error messages.
  late int _compilationId;

  /// [_compilationId], serialized as a varint.
  ///
  /// This is used in outgoing messages.
  late Uint8List _compilationIdVarint;

  /// Whether a fatal error has occured during host request.
  var _asyncError = false;

  /// Creates a [Dispatcher] that sends and receives encoded protocol buffers
  /// over [channel].
  Dispatcher(this._mailbox, this._sink);

  /// Listens for incoming `CompileRequests` and runs their compilations.
  void listen() {
    do {
      var packet = _mailbox.take();
      if (packet.isEmpty) break;

      try {
        var (compilationId, messageBuffer) = parsePacket(packet);

        _compilationId = compilationId;
        _compilationIdVarint = serializeVarint(compilationId);

        InboundMessage message;
        try {
          message = InboundMessage.fromBuffer(messageBuffer);
        } on InvalidProtocolBufferException catch (error) {
          throw parseError(error.message);
        }

        switch (message.whichMessage()) {
          case InboundMessage_Message.compileRequest:
            var request = message.compileRequest;
            var response = _compile(request);
            if (!_asyncError) {
              _send(OutboundMessage()..compileResponse = response);
            }

          case InboundMessage_Message.versionRequest:
            throw paramsError("VersionRequest must have compilation ID 0.");

          case InboundMessage_Message.canonicalizeResponse:
          case InboundMessage_Message.importResponse:
          case InboundMessage_Message.fileImportResponse:
          case InboundMessage_Message.functionCallResponse:
            throw paramsError(
                "Response ID ${message.id} doesn't match any outstanding requests in compilation $_compilationId.");

          case InboundMessage_Message.notSet:
            throw parseError("InboundMessage.message is not set.");

          default:
            throw parseError(
                "Unknown message type: ${message.toDebugString()}");
        }
      } catch (error, stackTrace) {
        _handleError(error, stackTrace);
      }
    } while (!_asyncError);
  }

  OutboundMessage_CompileResponse _compile(
      InboundMessage_CompileRequest request) {
    var functions = FunctionRegistry();

    var style = request.style == OutputStyle.COMPRESSED
        ? sass.OutputStyle.compressed
        : sass.OutputStyle.expanded;
    var logger = EmbeddedLogger(this,
        color: request.alertColor, ascii: request.alertAscii);

    try {
      var importers = request.importers.map((importer) =>
          _decodeImporter(request, importer) ??
          (throw mandatoryError("Importer.importer")));

      var globalFunctions = request.globalFunctions
          .map((signature) => hostCallable(this, functions, signature));

      late sass.CompileResult result;
      switch (request.whichInput()) {
        case InboundMessage_CompileRequest_Input.string:
          var input = request.string;
          result = sass.compileStringToResult(input.source,
              color: request.alertColor,
              logger: logger,
              importers: importers,
              importer: _decodeImporter(request, input.importer) ??
                  (input.url.startsWith("file:") ? null : sass.Importer.noOp),
              functions: globalFunctions,
              syntax: syntaxToSyntax(input.syntax),
              style: style,
              url: input.url.isEmpty ? null : input.url,
              quietDeps: request.quietDeps,
              verbose: request.verbose,
              sourceMap: request.sourceMap,
              charset: request.charset);

        case InboundMessage_CompileRequest_Input.path:
          if (request.path.isEmpty) {
            throw mandatoryError("CompileRequest.Input.path");
          }

          try {
            result = sass.compileToResult(request.path,
                color: request.alertColor,
                logger: logger,
                importers: importers,
                functions: globalFunctions,
                style: style,
                quietDeps: request.quietDeps,
                verbose: request.verbose,
                sourceMap: request.sourceMap,
                charset: request.charset);
          } on FileSystemException catch (error) {
            return OutboundMessage_CompileResponse()
              ..failure = (OutboundMessage_CompileResponse_CompileFailure()
                ..message = error.path == null
                    ? error.message
                    : "${error.message}: ${error.path}"
                ..span = (SourceSpan()
                  ..start = SourceSpan_SourceLocation()
                  ..end = SourceSpan_SourceLocation()
                  ..url = p.toUri(request.path).toString()));
          }

        case InboundMessage_CompileRequest_Input.notSet:
          throw mandatoryError("CompileRequest.input");
      }

      var success = OutboundMessage_CompileResponse_CompileSuccess()
        ..css = result.css;

      var sourceMap = result.sourceMap;
      if (sourceMap != null) {
        success.sourceMap = json.encode(sourceMap.toJson(
            includeSourceContents: request.sourceMapIncludeSources));
      }
      return OutboundMessage_CompileResponse()
        ..success = success
        ..loadedUrls.addAll(result.loadedUrls.map((url) => url.toString()));
    } on sass.SassException catch (error) {
      var formatted = withGlyphs(
          () => error.toString(color: request.alertColor),
          ascii: request.alertAscii);
      return OutboundMessage_CompileResponse()
        ..failure = (OutboundMessage_CompileResponse_CompileFailure()
          ..message = error.message
          ..span = protofySpan(error.span)
          ..stackTrace = error.trace.toString()
          ..formatted = formatted)
        ..loadedUrls.addAll(error.loadedUrls.map((url) => url.toString()));
    }
  }

  /// Converts [importer] into a [sass.Importer].
  sass.Importer? _decodeImporter(InboundMessage_CompileRequest request,
      InboundMessage_CompileRequest_Importer importer) {
    switch (importer.whichImporter()) {
      case InboundMessage_CompileRequest_Importer_Importer.path:
        return sass.FilesystemImporter(importer.path);

      case InboundMessage_CompileRequest_Importer_Importer.importerId:
        return HostImporter(this, importer.importerId);

      case InboundMessage_CompileRequest_Importer_Importer.fileImporterId:
        return FileImporter(this, importer.fileImporterId);

      case InboundMessage_CompileRequest_Importer_Importer.notSet:
        return null;
    }
  }

  /// Sends [event] to the host.
  void sendLog(OutboundMessage_LogEvent event) =>
      _send(OutboundMessage()..logEvent = event);

  /// Sends [error] to the host.
  void sendError(ProtocolError error) =>
      _send(OutboundMessage()..error = error);

  InboundMessage_CanonicalizeResponse sendCanonicalizeRequest(
          OutboundMessage_CanonicalizeRequest request) =>
      _sendRequest<InboundMessage_CanonicalizeResponse>(
          OutboundMessage()..canonicalizeRequest = request);

  InboundMessage_ImportResponse sendImportRequest(
          OutboundMessage_ImportRequest request) =>
      _sendRequest<InboundMessage_ImportResponse>(
          OutboundMessage()..importRequest = request);

  InboundMessage_FileImportResponse sendFileImportRequest(
          OutboundMessage_FileImportRequest request) =>
      _sendRequest<InboundMessage_FileImportResponse>(
          OutboundMessage()..fileImportRequest = request);

  InboundMessage_FunctionCallResponse sendFunctionCallRequest(
          OutboundMessage_FunctionCallRequest request) =>
      _sendRequest<InboundMessage_FunctionCallResponse>(
          OutboundMessage()..functionCallRequest = request);

  /// Sends [request] to the host and returns the message sent in response.
  T _sendRequest<T extends GeneratedMessage>(OutboundMessage message) {
    message.id = _outboundRequestId;
    _send(message);

    var packet = _mailbox.take();

    try {
      var messageBuffer =
          Uint8List.sublistView(packet, _compilationIdVarint.length);

      InboundMessage message;
      try {
        message = InboundMessage.fromBuffer(messageBuffer);
      } on InvalidProtocolBufferException catch (error) {
        throw parseError(error.message);
      }

      GeneratedMessage response;
      switch (message.whichMessage()) {
        case InboundMessage_Message.canonicalizeResponse:
          response = message.canonicalizeResponse;

        case InboundMessage_Message.importResponse:
          response = message.importResponse;

        case InboundMessage_Message.fileImportResponse:
          response = message.fileImportResponse;

        case InboundMessage_Message.functionCallResponse:
          response = message.functionCallResponse;

        case InboundMessage_Message.compileRequest:
          throw paramsError(
              "A CompileRequest with compilation ID $_compilationId is already active.");

        case InboundMessage_Message.versionRequest:
          throw paramsError("VersionRequest must have compilation ID 0.");

        case InboundMessage_Message.notSet:
          throw parseError("InboundMessage.message is not set.");

        default:
          throw parseError("Unknown message type: ${message.toDebugString()}");
      }
      if (message.id != _outboundRequestId) {
        throw paramsError(
            "Response ID ${message.id} doesn't match any outstanding requests in compilation $_compilationId.");
      }
      if (response is! T) {
        throw paramsError(
            "Request ID $_outboundRequestId doesn't match response type ${response.runtimeType} in compilation $_compilationId.");
      }
      return response;
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
      _asyncError = true;
      rethrow;
    }
  }

  /// Handles an error thrown by the dispatcher or code it dispatches to.
  ///
  /// The [messageId] indicate the IDs of the message being responded to, if available.
  void _handleError(Object error, StackTrace stackTrace, {int? messageId}) {
    sendError(handleError(error, stackTrace, messageId: messageId));
    _sink.close();
  }

  /// Sends [message] to the host with the given [wireId].
  void _send(OutboundMessage message) {
    var protobufWriter = CodedBufferWriter();
    message.writeToCodedBufferWriter(protobufWriter);

    // Add one additional byte to the beginning to indicate whether or not the
    // compilation is finished, so the [IsolateDispatcher] knows whether to
    // treat this isolate as inactive.
    var packet = Uint8List(
        1 + _compilationIdVarint.length + protobufWriter.lengthInBytes);
    packet[0] =
        message.whichMessage() == OutboundMessage_Message.compileResponse
            ? 1
            : 0;
    packet.setAll(1, _compilationIdVarint);
    protobufWriter.writeTo(packet, 1 + _compilationIdVarint.length);
    _sink.add(packet);
  }
}
