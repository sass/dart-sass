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

/// A class that dispatches messages to and from the host.
class Dispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

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
      InboundMessage message;
      try {
        try {
          message = InboundMessage.fromBuffer(binaryMessage);
        } on InvalidProtocolBufferException catch (error) {
          throw _parseError(error.message);
        }

        switch (message.whichMessage()) {
          case InboundMessage_Message.error:
            var error = message.ensureError();
            stderr
                .write("Host reported ${error.type.name.toLowerCase()} error");
            if (error.id != -1) stderr.write(" with request ${error.id}");
            stderr.writeln(": ${error.message}");
            // SOFTWARE error from https://bit.ly/2poTt90
            exitCode = 70;
            _channel.sink.close();
            break;

          case InboundMessage_Message.compileRequest:
            var request = message.ensureCompileRequest();
            var response = await callback(request);
            response.id = request.id;
            _send(OutboundMessage()..compileResponse = response);
            break;

          case InboundMessage_Message.notSet:
            // PROTOCOL error from https://bit.ly/2poTt90
            exitCode = 76;
            throw _parseError("InboundMessage.message is not set.");

          default:
            // PROTOCOL error from https://bit.ly/2poTt90
            exitCode = 76;
            throw _parseError(
                "Unknown message type: ${message.toDebugString()}");
        }
      } on ProtocolError catch (error) {
        error.id = _messageId(message) ?? -1;
        stderr.write("Host caused ${error.type.name.toLowerCase()} error");
        if (error.id != -1) stderr.write(" with request ${error.id}");
        stderr.writeln(": ${error.message}");
        _send(OutboundMessage()..error = error);
      } catch (error, stackTrace) {
        var errorMessage = "$error\n${Chain.forTrace(stackTrace)}";
        stderr.write("Internal compiler error: $errorMessage");
        _send(OutboundMessage()
          ..error = (ProtocolError()
            ..type = ProtocolError_ErrorType.INTERNAL
            ..id = _messageId(message) ?? -1
            ..message = errorMessage));
        _channel.sink.close();
      }
    });
  }

  /// Sends [event] to the host.
  void sendLog(OutboundMessage_LogEvent event) =>
      _send(OutboundMessage()..logEvent = event);

  /// Sends [message] to the host.
  void _send(OutboundMessage message) =>
      _channel.sink.add(message.writeToBuffer());

  /// Returns a [ProtocolError] with type `PARSE` and the given [message].
  ProtocolError _parseError(String message) => ProtocolError()
    ..type = ProtocolError_ErrorType.PARSE
    ..message = message;

  /// Returns the id for [message] if it it's a request or response, or `null`
  /// otherwise.
  int _messageId(InboundMessage message) {
    if (message == null) return null;
    switch (message.whichMessage()) {
      case InboundMessage_Message.compileRequest:
        return message.ensureCompileRequest().id;
      case InboundMessage_Message.canonicalizeResponse:
        return message.ensureCanonicalizeResponse().id;
      case InboundMessage_Message.importResponse:
        return message.ensureImportResponse().id;
      case InboundMessage_Message.functionCallRequest:
        return message.ensureFunctionCallRequest().id;
      case InboundMessage_Message.functionCallResponse:
        return message.ensureFunctionCallResponse().id;
      default:
        return null;
    }
  }
}
