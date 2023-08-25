// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:native_synchronization/sendable.dart';
import 'package:pool/pool.dart';
import 'package:protobuf/protobuf.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

import 'dispatcher.dart';
import 'embedded_sass.pb.dart';
import 'util/explicit_close_transformer.dart';
import 'util/proto_extensions.dart';
import 'utils.dart';

/// A persisted mailbox resource lease from the pool that can be transfered over
/// to new owners.
class _Lease {
  /// A mailbox.
  final Mailbox mailbox;

  /// The compilationId.
  int id = 0;

  /// The PoolResource.
  PoolResource resource;

  _Lease(this.mailbox, this.id, this.resource);
}

/// A class that dispatches messages between the host and various isolates that
/// are each running an individual compilation.
class IsolateDispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

  /// The actual isolate objects that have been spawned.
  ///
  /// Only used for cleaning up the process when the underlying channel closes.
  final _allIsolates = <Future<Isolate>>[];

  /// All sinks. Only used with ExplicitCloseTransformer for closing channels.
  final _sinks = <StreamSink<Uint8List>>{};

  /// A set of lease for tracking for inactive mailboxes.
  final _inactive = <_Lease>{};

  /// A map of active compilationId to mailbox.
  final _mailboxes = <int, Mailbox>{};

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
          var mailbox =
              (_mailboxes[compilationId] ?? await _getMailbox(compilationId));
          try {
            mailbox.put(packet);
            return;
          } on StateError catch (_) {
            throw paramsError(
                "InboundMessage with compilation ID $compilationId is out of order.");
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

      for (var sink in _sinks) {
        sink.close();
      }
    });
  }

  /// Returns the mailbox for an isolate that's ready to run a new compilation.
  ///
  /// This re-uses an existing isolate if possible, and spawns a new one
  /// otherwise.
  Future<Mailbox> _getMailbox(int compilationId) async {
    var resource = await _isolatePool.request();
    if (_inactive.isNotEmpty) {
      var lease = _inactive.first;
      _inactive.remove(lease);
      lease.id = compilationId;
      lease.resource = resource;
      _mailboxes[compilationId] = lease.mailbox;
      return lease.mailbox;
    }

    var mailbox = Mailbox();
    var lease = _Lease(mailbox, compilationId, resource);
    _mailboxes[compilationId] = mailbox;

    var receivePort = ReceivePort();
    var future =
        Isolate.spawn(_isolateMain, (mailbox.asSendable, receivePort.sendPort));
    _allIsolates.add(future);
    await future;

    var channel = IsolateChannel<Uint8List?>.connectReceive(receivePort)
        .transform(const ExplicitCloseTransformer());
    _sinks.add(channel.sink);

    channel.stream.listen((message) {
      // The first byte of messages from isolates indicates whether the
      // entire compilation is finished. Sending this as part of the message
      // buffer rather than a separate message avoids a race condition where
      // the host might send a new compilation request with the same ID as
      // one that just finished before the [IsolateDispatcher] receives word
      // that the isolate with that ID is done. See sass/dart-sass#2004.
      if (message[0] == 1) {
        _mailboxes.remove(lease.id);
        _inactive.add(lease);
        lease.resource.release();
      }
      _channel.sink.add(Uint8List.sublistView(message, 1));
    }, onError: (Object error, StackTrace stackTrace) {
      _handleError(error, stackTrace);
    }, onDone: () {
      try {
        mailbox.put(Uint8List(0));
      } on StateError catch (_) {}
      _channel.sink.close();
    });
    return mailbox;
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

void _isolateMain((Sendable<Mailbox>, SendPort) message) {
  var (sendableMailbox, sendPort) = message;
  var mailbox = sendableMailbox.materialize();
  var sink = IsolateChannel<Uint8List?>.connectSend(sendPort)
      .transform(const ExplicitCloseTransformer())
      .sink;
  Dispatcher(mailbox, sink).listen();
}
