// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pool/pool.dart';
import 'package:protobuf/protobuf.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

import 'dispatcher.dart';
import 'embedded_sass.pb.dart';
import 'util/explicit_close_transformer.dart';
import 'util/proto_extensions.dart';
import 'utils.dart';

/// The message sent to a previously-inactive isolate to initiate a new
/// compilation session.
///
/// The [SendPort] is used to establish a dedicated [IsolateChannel] for this
/// compilation and the [int] is the compilation ID to use on the wire.
///
/// We apply the compilation ID in the isolate for efficiency reasons: it allows
/// us to write the protobuf directly to the same buffer as the wire ID, which
/// saves a copy for each message.
typedef _InitialMessage = (SendPort, int);

/// A class that dispatches messages between the host and various isolates that
/// are each running an individual compilation.
class IsolateDispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

  /// A map from compilation IDs to the sinks for isolates running those
  /// compilations.
  final _activeIsolates = <int, StreamSink<Uint8List>>{};

  /// A set of isolates that are _not_ actively running compilations.
  final _inactiveIsolates = <StreamChannel<_InitialMessage>>{};

  /// The actual isolate objects that have been spawned.
  ///
  /// Only used for cleaning up the process when the underlying channel closes.
  final _allIsolates = <Isolate>[];

  /// A pool controlling how many isolates (and thus concurrent compilations)
  /// may be live at once.
  ///
  /// More than 15 concurrent `waitFor()` calls seems to deadlock the Dart VM,
  /// even across isolates. See sass/dart-sass#1959.
  final _isolatePool = Pool(15);

  IsolateDispatcher(this._channel);

  void listen() {
    _channel.stream.listen((packet) async {
      int? compilationId;
      InboundMessage? message;
      try {
        Uint8List messageBuffer;
        (compilationId, messageBuffer) = parsePacket(packet);

        if (compilationId != 0) {
          // TODO(nweiz): Consider using the techniques described in
          // https://github.com/dart-lang/language/issues/124#issuecomment-988718728
          // or https://github.com/dart-lang/language/issues/3118 for low-cost
          // inter-isolate transfers.
          (_activeIsolates[compilationId] ?? await _getIsolate(compilationId))
              .add(messageBuffer);
          return;
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
      for (var isolate in _allIsolates) {
        isolate.kill();
      }

      // Killing isolates isn't sufficient to make sure the process closes; we
      // also have to close all the [ReceivePort]s we've constructed (by closing
      // the [IsolateChannel]s).
      for (var sink in _activeIsolates.values) {
        sink.close();
      }
      for (var channel in _inactiveIsolates) {
        channel.sink.close();
      }
    });
  }

  /// Returns an isolate that's ready to run a new compilation.
  ///
  /// This re-uses an existing isolate if possible, and spawns a new one
  /// otherwise.
  Future<StreamSink<Uint8List>> _getIsolate(int compilationId) async {
    var resource = await _isolatePool.request();
    if (_inactiveIsolates.isNotEmpty) {
      return _activate(_inactiveIsolates.first, compilationId, resource);
    }

    var receivePort = ReceivePort();
    await Isolate.spawn(_isolateMain, receivePort.sendPort);

    var channel = IsolateChannel<_InitialMessage?>.connectReceive(receivePort)
        .transform(const ExplicitCloseTransformer());
    channel.stream.listen(null,
        onError: (Object error, StackTrace stackTrace) =>
            _handleError(error, stackTrace),
        onDone: _channel.sink.close);
    return _activate(channel, compilationId, resource);
  }

  /// Activates [isolate] for a new individual compilation.
  ///
  /// This pipes all the outputs from the given isolate through to [_channel].
  /// The [resource] is released once the isolate is no longer active.
  StreamSink<Uint8List> _activate(StreamChannel<_InitialMessage> isolate,
      int compilationId, PoolResource resource) {
    _inactiveIsolates.remove(isolate);

    // Each individual compilation has its own dedicated [IsolateChannel], which
    // closes once the compilation is finished.
    var receivePort = ReceivePort();
    isolate.sink.add((receivePort.sendPort, compilationId));

    var channel = IsolateChannel<Uint8List?>.connectReceive(receivePort)
        .transform(const ExplicitCloseTransformer());
    channel.stream.listen(_channel.sink.add,
        onError: (Object error, StackTrace stackTrace) =>
            _handleError(error, stackTrace),
        onDone: () {
          _activeIsolates.remove(compilationId);
          _inactiveIsolates.add(isolate);
          resource.release();
          channel.sink.close();
        });
    _activeIsolates[compilationId] = channel.sink;
    return channel.sink;
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
    if (error is ProtocolError) {
      error.id = messageId ?? errorId;
      stderr.write("Host caused ${error.type.name.toLowerCase()} error");
      if (error.id != errorId) stderr.write(" with request ${error.id}");
      stderr.writeln(": ${error.message}");
      sendError(compilationId ?? errorId, error);
      // PROTOCOL error from https://bit.ly/2poTt90
      exitCode = 76;
      _channel.sink.close();
    } else {
      var errorMessage = "$error\n${Chain.forTrace(stackTrace)}";
      stderr.write("Internal compiler error: $errorMessage");
      sendError(
          compilationId ?? errorId,
          ProtocolError()
            ..type = ProtocolErrorType.INTERNAL
            ..id = messageId ?? errorId
            ..message = errorMessage);
      _channel.sink.close();
    }
  }

  /// Sends [message] to the host.
  void _send(int compilationId, OutboundMessage message) =>
      _channel.sink.add(serializePacket(compilationId, message));

  /// Sends [error] to the host.
  void sendError(int compilationId, ProtocolError error) =>
      _send(compilationId, OutboundMessage()..error = error);
}

void _isolateMain(SendPort sendPort) {
  var channel = IsolateChannel<_InitialMessage?>.connectSend(sendPort)
      .transform(const ExplicitCloseTransformer());
  channel.stream.listen((initialMessage) async {
    var (compilationSendPort, compilationId) = initialMessage;
    var compilationChannel =
        IsolateChannel<Uint8List?>.connectSend(compilationSendPort)
            .transform(const ExplicitCloseTransformer());
    var success = await Dispatcher(compilationChannel, compilationId).listen();
    if (!success) channel.sink.close();
  });
}
