// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:pool/pool.dart';
import 'package:protobuf/protobuf.dart';
import 'package:stream_channel/stream_channel.dart';

import 'compilation_dispatcher.dart';
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
  final _allIsolates = StreamController<ReusableIsolate>(sync: true);

  /// The isolates that aren't currently running compilations
  final _inactiveIsolates = <ReusableIsolate>{};

  /// A map from active compilationIds to isolates running those compilations.
  final _activeIsolates = <int, Future<ReusableIsolate>>{};

  /// A pool controlling how many isolates (and thus concurrent compilations)
  /// may be live at once.
  ///
  /// More than MaxMutatorThreadCount isolates in the same isolate group
  /// can deadlock the Dart VM.
  /// See https://github.com/sass/dart-sass/pull/2019
  final _isolatePool = Pool(sizeOf<IntPtr>() <= 4 ? 7 : 15);

  /// Whether the stdin has been closed or not.
  bool _closed = false;

  IsolateDispatcher(this._channel);

  void listen() {
    _channel.stream.listen((packet) async {
      int? compilationId;
      InboundMessage? message;
      try {
        Uint8List messageBuffer;
        (compilationId, messageBuffer) = parsePacket(packet);

        if (compilationId != 0) {
          var isolate = await _activeIsolates.putIfAbsent(
              compilationId, () => _getIsolate(compilationId!));

          // The shutdown may have started by the time the isolate is spawned
          if (_closed) {
            return;
          }

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
    }, onDone: () {
      _closed = true;
      _allIsolates.stream.listen((isolate) => isolate.kill());
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
      isolate = await future;
      isolate.receivePort.listen((message) {
        assert(isolate.borrowed,
            "Shouldn't receive a message before being borrowed.");

        var fullBuffer = message as Uint8List;

        // The first byte of messages from isolates indicates whether the entire
        // compilation is finished (1) or if it encountered an error (2). Sending
        // this as part of the message buffer rather than a separate message
        // avoids a race condition where the host might send a new compilation
        // request with the same ID as one that just finished before the
        // [IsolateDispatcher] receives word that the isolate with that ID is
        // done. See sass/dart-sass#2004.
        var category = fullBuffer[0];
        var packet = Uint8List.sublistView(fullBuffer, 1);

        switch (category) {
          case 0:
            _channel.sink.add(packet);
          case 1:
            _activeIsolates.remove(compilationId);
            _inactiveIsolates.add(isolate);
            _channel.sink.add(packet);
            isolate.release();
          case 2:
            _channel.sink.add(packet);
            exit(exitCode);
        }
      }, onError: (Object error, StackTrace stackTrace) {
        _handleError(error, stackTrace);
      });
      _allIsolates.add(isolate);
    }

    isolate.borrow(resource);

    return isolate;
  }

  /// Creates a [OutboundMessage_VersionResponse]
  static OutboundMessage_VersionResponse versionResponse() {
    return OutboundMessage_VersionResponse()
      ..protocolVersion = const String.fromEnvironment("protocol-version")
      ..compilerVersion = const String.fromEnvironment("compiler-version")
      ..implementationVersion = const String.fromEnvironment("compiler-version")
      ..implementationName = "dart-sass";
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
  CompilationDispatcher(mailbox, sendPort).listen();
}
