// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:pool/pool.dart';
import 'package:protobuf/protobuf.dart';
import 'package:stream_channel/stream_channel.dart';

import 'dispatcher.dart';
import 'embedded_sass.pb.dart';
import 'reusable_isolate.dart';
import 'util/proto_extensions.dart';
import 'utils.dart';

/// A class that dispatches messages between the host and various isolates that
/// are each running an individual compilation.
class IsolateDispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

  /// All isolates that have been spawned to dispatch to.
  ///
  /// Only used for cleaning up the process when the underlying channel closes.
  final _allIsolates = <Future<ReusableIsolate>>[];

  /// The isolates that aren't currently running compilations
  final _inactiveIsolates = <ReusableIsolate>{};

  /// A map from active compilationIds to isolates running those compilations.
  final _activeIsolates = <int, ReusableIsolate>{};

  /// A pool controlling how many isolates (and thus concurrent compilations)
  /// may be live at once.
  ///
  /// More than MaxMutatorThreadCount isolates in the same isolate group
  /// can deadlock the Dart VM.
  /// See https://github.com/sass/dart-sass/pull/2019
  final _isolatePool = Pool(sizeOf<IntPtr>() <= 4 ? 7 : 15);

  IsolateDispatcher(this._channel);

  void listen() {
    _channel.stream.listen((packet) async {
      int? compilationId;
      InboundMessage? message;
      try {
        Uint8List messageBuffer;
        (compilationId, messageBuffer) = parsePacket(packet);

        if (compilationId != 0) {
          var isolate = _activeIsolates[compilationId] ??
              await _getIsolate(compilationId);
          try {
            isolate.send(packet);
            return;
          } on StateError catch (_) {
            throw paramsError(
                "Received multiple messages for compilation ID $compilationId");
          }
        }

        try {
          message = InboundMessage.fromBuffer(messageBuffer);
        } on InvalidProtocolBufferException catch (error) {
          throw parseError(error.message);
        }

        if (message.whichMessage() case var type
            when type != InboundMessage_Message.versionRequest) {
          throw paramsError(
              "Only VersionRequest may have wire ID 0, was $type.");
        }

        var request = message.versionRequest;
        var response = versionResponse();
        response.id = request.id;
        _send(0, OutboundMessage()..versionResponse = response);
      } catch (error, stackTrace) {
        _handleError(error, stackTrace,
            compilationId: compilationId, messageId: message?.id);
      }
    }, onError: (Object error, StackTrace stackTrace) {
      _handleError(error, stackTrace);
    }, onDone: () async {
      for (var isolate in _allIsolates) {
        (await isolate).kill();
      }
    });
  }

  /// Returns an isolate that's ready to run a new compilation.
  ///
  /// This re-uses an existing isolate if possible, and spawns a new one
  /// otherwise.
  Future<ReusableIsolate> _getIsolate(int compilationId) async {
    var resource = await _isolatePool.request();
    ReusableIsolate isolate;
    if (_inactiveIsolates.isNotEmpty) {
      isolate = _inactiveIsolates.first;
      _inactiveIsolates.remove(isolate);
    } else {
      var future = ReusableIsolate.spawn(_isolateMain);
      _allIsolates.add(future);
      isolate = await future;
    }

    _activeIsolates[compilationId] = isolate;
    isolate.checkOut().listen(_channel.sink.add,
        onError: (Object error, StackTrace stackTrace) {
      if (error is ProtocolError) {
        // Protocol errors have already been through [_handleError] in the child
        // isolate, so we just send them as-is and close out the underlying
        // channel.
        sendError(compilationId, error);
        _channel.sink.close();
      } else {
        _handleError(error, stackTrace);
      }
    }, onDone: () {
      _activeIsolates.remove(compilationId);
      _inactiveIsolates.add(isolate);
      resource.release();
    });

    return isolate;
  }

  /// Creates a [OutboundMessage_VersionResponse]
  static OutboundMessage_VersionResponse versionResponse() {
    return OutboundMessage_VersionResponse()
      ..protocolVersion = const String.fromEnvironment("protocol-version")
      ..compilerVersion = const String.fromEnvironment("compiler-version")
      ..implementationVersion = const String.fromEnvironment("compiler-version")
      ..implementationName = "Dart Sass";
  }

  /// Handles an error thrown by the dispatcher or code it dispatches to.
  ///
  /// The [compilationId] and [messageId] indicate the IDs of the message being
  /// responded to, if available.
  void _handleError(Object error, StackTrace stackTrace,
      {int? compilationId, int? messageId}) {
    sendError(compilationId ?? errorId,
        handleError(error, stackTrace, messageId: messageId));
    _channel.sink.close();
  }

  /// Sends [message] to the host.
  void _send(int compilationId, OutboundMessage message) =>
      _channel.sink.add(serializePacket(compilationId, message));

  /// Sends [error] to the host.
  void sendError(int compilationId, ProtocolError error) =>
      _send(compilationId, OutboundMessage()..error = error);
}

void _isolateMain(Mailbox mailbox, SendPort sendPort) {
  Dispatcher(mailbox, sendPort).listen();
}
