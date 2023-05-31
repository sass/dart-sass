// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:protobuf/protobuf.dart';
import 'package:sass/sass.dart' as sass;
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

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
class Dispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

  /// The compilation ID for which this dispatcher is running.
  ///
  /// This is added to outgoing messages but is _not_ parsed from incoming
  /// messages, since that's already handled by the [IsolateDispatcher].
  final int _compilationId;

  /// [_compilationId], serialized as a varint.
  final Uint8List _compilationIdVarint;

  /// A completer awaiting a response to an outbound request.
  ///
  /// Since each [Dispatcher] is only running a single-threaded compilation, it
  /// can only ever have one request outstanding.
  Completer<GeneratedMessage>? _outstandingRequest;

  /// Creates a [Dispatcher] that sends and receives encoded protocol buffers
  /// over [channel].
  Dispatcher(this._channel, this._compilationId) :
  _compilationIdVarint = serializeVarint(_compilationId);

  /// Listens for incoming `CompileRequests` and runs their compilations.
  ///
  /// This may only be called once.
  void listen() {
    _channel.stream.listen((binaryMessage) async {
      InboundMessage? message;
      try {
        try {
          message = InboundMessage.fromBuffer(binaryMessage);
        } on InvalidProtocolBufferException catch (error) {
          throw parseError(error.message);
        }

        switch (message.whichMessage()) {
          case InboundMessage_Message.versionRequest:
          // TODO before submit: Figure out which errors end the compilation and
          // which are recoverable. Make sure we deactivate an isolate if its
          // first request isn't a `CompilationRequest`.
            throw paramsError("VersionRequest must have compilation ID 0.");

          case InboundMessage_Message.compileRequest:
            var request = message.compileRequest;
            var response = await _compile(request);
            _send(OutboundMessage()..compileResponse = response);
            // Each Dispatcher runs a single compilation and then closes.
            _channel.sink.close();

          case InboundMessage_Message.canonicalizeResponse:
            _dispatchResponse(message.id, message.canonicalizeResponse);

          case InboundMessage_Message.importResponse:
            _dispatchResponse(message.id, message.importResponse);

          case InboundMessage_Message.fileImportResponse:
            _dispatchResponse(message.id, message.fileImportResponse);

          case InboundMessage_Message.functionCallResponse:
            _dispatchResponse(message.id, message.functionCallResponse);

          case InboundMessage_Message.notSet:
            throw parseError("InboundMessage.message is not set.");

          default:
            throw parseError(
                "Unknown message type: ${message.toDebugString()}");
        }
      } on ProtocolError catch (error) {
        error.id = message?.id ?? errorId;
        stderr.write("Host caused ${error.type.name.toLowerCase()} error");
        if (error.id != errorId) stderr.write(" with request ${error.id}");
        stderr.writeln(": ${error.message}");
        sendError(error);
        // PROTOCOL error from https://bit.ly/2poTt90
        exitCode = 76;
        _channel.sink.close();
      } catch (error, stackTrace) {
        var errorMessage = "$error\n${Chain.forTrace(stackTrace)}";
        stderr.write("Internal compiler error: $errorMessage");
        sendError(ProtocolError()
          ..type = ProtocolErrorType.INTERNAL
          ..id = message?.id ?? errorId
          ..message = errorMessage);
        _channel.sink.close();
      }
    });
  }

  Future<OutboundMessage_CompileResponse> _compile(
      InboundMessage_CompileRequest request) async {
    var functions = FunctionRegistry();

    var style = request.style == OutputStyle.COMPRESSED
        ? sass.OutputStyle.compressed
        : sass.OutputStyle.expanded;
    var logger = EmbeddedLogger(this, request.id,
        color: request.alertColor, ascii: request.alertAscii);

    try {
      var importers = request.importers.map((importer) =>
          _decodeImporter(request, importer) ??
          (throw mandatoryError("Importer.importer")));

      var globalFunctions = request.globalFunctions.map((signature) {
        try {
          return hostCallable(this, functions, request.id, signature);
        } on sass.SassException catch (error) {
          throw paramsError('CompileRequest.global_functions: $error');
        }
      });

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
          break;

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
          break;

        case InboundMessage_CompileRequest_Input.notSet:
          throw mandatoryError("CompileRequest.input");
      }

      var success = OutboundMessage_CompileResponse_CompileSuccess()
        ..css = result.css
        ..loadedUrls.addAll(result.loadedUrls.map((url) => url.toString()));

      var sourceMap = result.sourceMap;
      if (sourceMap != null) {
        success.sourceMap = json.encode(sourceMap.toJson(
            includeSourceContents: request.sourceMapIncludeSources));
      }
      return OutboundMessage_CompileResponse()..success = success;
    } on sass.SassException catch (error) {
      var formatted = withGlyphs(
          () => error.toString(color: request.alertColor),
          ascii: request.alertAscii);
      return OutboundMessage_CompileResponse()
        ..failure = (OutboundMessage_CompileResponse_CompileFailure()
          ..message = error.message
          ..span = protofySpan(error.span)
          ..stackTrace = error.trace.toString()
          ..formatted = formatted);
    }
  }

  /// Converts [importer] into a [sass.Importer].
  sass.Importer? _decodeImporter(InboundMessage_CompileRequest request,
      InboundMessage_CompileRequest_Importer importer) {
    switch (importer.whichImporter()) {
      case InboundMessage_CompileRequest_Importer_Importer.path:
        return sass.FilesystemImporter(importer.path);

      case InboundMessage_CompileRequest_Importer_Importer.importerId:
        return HostImporter(this, request.id, importer.importerId);

      case InboundMessage_CompileRequest_Importer_Importer.fileImporterId:
        return FileImporter(this, request.id, importer.fileImporterId);

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

  Future<InboundMessage_CanonicalizeResponse> sendCanonicalizeRequest(
          OutboundMessage_CanonicalizeRequest request) =>
      _sendRequest<InboundMessage_CanonicalizeResponse>(
          OutboundMessage()..canonicalizeRequest = request);

  Future<InboundMessage_ImportResponse> sendImportRequest(
          OutboundMessage_ImportRequest request) =>
      _sendRequest<InboundMessage_ImportResponse>(
          OutboundMessage()..importRequest = request);

  Future<InboundMessage_FileImportResponse> sendFileImportRequest(
          OutboundMessage_FileImportRequest request) =>
      _sendRequest<InboundMessage_FileImportResponse>(
          OutboundMessage()..fileImportRequest = request);

  Future<InboundMessage_FunctionCallResponse> sendFunctionCallRequest(
          OutboundMessage_FunctionCallRequest request) =>
      _sendRequest<InboundMessage_FunctionCallResponse>(
          OutboundMessage()..functionCallRequest = request);

  /// Sends [request] to the host and returns the message sent in response.
  Future<T> _sendRequest<T extends GeneratedMessage>(
      OutboundMessage request) async {
    request.id = _outboundRequestId;
    _send(request);

    if (_outstandingRequest != null) {
      throw StateError(
        "Dispatcher.sendRequest() can't be called when another request is "
        "active.");
    }

    return (_outstandingRequest = Completer<T>()).future;
  }

  /// Dispatches [response] to the appropriate outstanding request.
  ///
  /// Throws an error if there's no outstanding request with the given [id] or
  /// if that request is expecting a different type of response.
  void _dispatchResponse<T extends GeneratedMessage>(int? id, T response) {
    var completer = _outstandingRequest;
    _outstandingRequest = null;
    if (completer == null || id != _outboundRequestId) {
      throw paramsError(
          "Response ID $id doesn't match any outstanding requests in "
          "compilation $_compilationId.");
    } else if (completer is! Completer<T>) {
      throw paramsError(
          "Request ID $id doesn't match response type ${response.runtimeType} "
          "in compilation $_compilationId.");
    }

    completer.complete(response);
  }

  /// Sends [message] to the host with the given [wireId].
  void _send(OutboundMessage message) {
    var protobufWriter = CodedBufferWriter();
    message.writeToCodedBufferWriter(protobufWriter);

    var packet = Uint8List(_compilationIdVarint.length + protobufWriter.lengthInBytes);
    packet.setAll(0, _compilationIdVarint);
    protobufWriter.writeTo(packet, _compilationIdVarint.length);
    _channel.sink.add(packet);
  }
}
