// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

import 'embedded_sass.pb.dart';
import 'utils.dart';

/// A class that dispatches messages to and from the host.
class Dispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

  /// Completers awaiting responses to outbound requests.
  ///
  /// The completers are located at indexes in this list matching the request
  /// IDs. `null` elements indicate IDs whose requests have been responded to,
  /// and which are therefore free to re-use.
  final _outstandingRequests = <Completer<GeneratedMessage>?>[];

  /// Creates a [Dispatcher] that sends and receives encoded protocol buffers
  /// over [channel].
  Dispatcher(this._channel);

  /// Listens for incoming `CompileRequests` and passes them to [callback].
  ///
  /// The callback must return a `CompileResponse` which is sent to the host.
  /// The callback may throw [ProtocolError]s, which will be sent back to the
  /// host. Neither `CompileResponse`s nor [ProtocolError]s need to set their
  /// `id` fields; the [Dispatcher] will take care of that.
  ///
  /// This may only be called once.
  void listen(
      FutureOr<OutboundMessage_CompileResponse> callback(
          InboundMessage_CompileRequest request)) {
    _channel.stream.listen((binaryMessage) async {
      // Wait a single microtask tick so that we're running in a separate
      // microtask from the initial request dispatch. Otherwise, [waitFor] will
      // deadlock the event loop fiber that would otherwise be checking stdin
      // for new input.
      await Future.value();

      InboundMessage? message;
      try {
        try {
          message = InboundMessage.fromBuffer(binaryMessage);
        } on InvalidProtocolBufferException catch (error) {
          throw _parseError(error.message);
        }

        switch (message.whichMessage()) {
          case InboundMessage_Message.compileRequest:
            var request = message.compileRequest;
            var response = await callback(request);
            response.id = request.id;
            _send(OutboundMessage()..compileResponse = response);
            break;

          case InboundMessage_Message.canonicalizeResponse:
            var response = message.canonicalizeResponse;
            _dispatchResponse(response.id, response);
            break;

          case InboundMessage_Message.importResponse:
            var response = message.importResponse;
            _dispatchResponse(response.id, response);
            break;

          case InboundMessage_Message.functionCallResponse:
            var response = message.functionCallResponse;
            _dispatchResponse(response.id, response);
            break;

          case InboundMessage_Message.notSet:
            throw _parseError("InboundMessage.message is not set.");

          default:
            throw _parseError(
                "Unknown message type: ${message.toDebugString()}");
        }
      } on ProtocolError catch (error) {
        error.id = _inboundId(message) ?? errorId;
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
          ..type = ProtocolError_ErrorType.INTERNAL
          ..id = _inboundId(message) ?? errorId
          ..message = errorMessage);
        _channel.sink.close();
      }
    });
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

  Future<InboundMessage_FunctionCallResponse> sendFunctionCallRequest(
          OutboundMessage_FunctionCallRequest request) =>
      _sendRequest<InboundMessage_FunctionCallResponse>(
          OutboundMessage()..functionCallRequest = request);

  /// Sends [request] to the host and returns the message sent in response.
  Future<T> _sendRequest<T extends GeneratedMessage>(
      OutboundMessage request) async {
    var id = _nextRequestId();
    _setOutboundId(request, id);
    _send(request);

    var completer = Completer<T>();
    _outstandingRequests[id] = completer;
    return completer.future;
  }

  /// Returns an available request ID, and guarantees that its slot is available
  /// in [_outstandingRequests].
  int _nextRequestId() {
    for (var i = 0; i < _outstandingRequests.length; i++) {
      if (_outstandingRequests[i] == null) return i;
    }

    // If there are no empty slots, add another one.
    _outstandingRequests.add(null);
    return _outstandingRequests.length - 1;
  }

  /// Dispatches [response] to the appropriate outstanding request.
  ///
  /// Throws an error if there's no outstanding request with the given [id] or
  /// if that request is expecting a different type of response.
  void _dispatchResponse<T extends GeneratedMessage>(int id, T response) {
    var completer =
        id < _outstandingRequests.length ? _outstandingRequests[id] : null;
    if (completer == null) {
      throw paramsError(
          "Response ID $id doesn't match any outstanding requests.");
    } else if (completer is! Completer<T>) {
      throw paramsError("Request ID $id doesn't match response type "
          "${response.runtimeType}.");
    }

    completer.complete(response);
  }

  /// Sends [message] to the host.
  void _send(OutboundMessage message) =>
      _channel.sink.add(message.writeToBuffer());

  /// Returns a [ProtocolError] with type `PARSE` and the given [message].
  ProtocolError _parseError(String message) => ProtocolError()
    ..type = ProtocolError_ErrorType.PARSE
    ..message = message;

  /// Returns the id for [message] if it it's a request, or `null`
  /// otherwise.
  int? _inboundId(InboundMessage? message) {
    if (message == null) return null;
    switch (message.whichMessage()) {
      case InboundMessage_Message.compileRequest:
        return message.compileRequest.id;
      default:
        return null;
    }
  }

  /// Sets the id for [message] to [id].
  ///
  /// Throws an [ArgumentError] if [message] doesn't have an id field.
  void _setOutboundId(OutboundMessage message, int id) {
    switch (message.whichMessage()) {
      case OutboundMessage_Message.compileResponse:
        message.compileResponse.id = id;
        break;
      case OutboundMessage_Message.canonicalizeRequest:
        message.canonicalizeRequest.id = id;
        break;
      case OutboundMessage_Message.importRequest:
        message.importRequest.id = id;
        break;
      case OutboundMessage_Message.functionCallRequest:
        message.functionCallRequest.id = id;
        break;
      default:
        break;
    }
  }
}
