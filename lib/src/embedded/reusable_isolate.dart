// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:native_synchronization/sendable.dart';
import 'embedded_sass.pb.dart';
import 'utils.dart';

/// The entrypoint for a [ReusableIsolate].
///
/// This must be a static global function. It's run when the isolate is spawned,
/// and is passed a [Mailbox] that receives messages from [ReusableIsolate.send]
/// and a [SendPort] that sends messages to the stream returned by
/// [ReusableIsolate.checkOut].
///
/// If the [sendPort] sends a message before [ReusableIsolate.checkOut] is
/// called, this will throw an unhandled [StateError].
typedef ReusableIsolateEntryPoint = FutureOr<void> Function(
    Mailbox mailbox, SendPort sink);

class ReusableIsolate {
  /// The wrapped isolate.
  final Isolate _isolate;

  /// The mailbox used to send messages to this isolate.
  final Mailbox _mailbox;

  /// The [ReceivePort] that receives messages from the wrapped isolate.
  final ReceivePort _receivePort;

  /// The subscription to [_port].
  final StreamSubscription<Object?> _subscription;

  /// Whether [checkOut] has been called and the returned stream has not yet
  /// closed.
  bool _checkedOut = false;

  ReusableIsolate._(this._isolate, this._mailbox, this._receivePort)
      : _subscription = _receivePort.listen(_defaultOnData);

  /// Spawns a [ReusableIsolate] that runs the given [entryPoint].
  static Future<ReusableIsolate> spawn(
      ReusableIsolateEntryPoint entryPoint) async {
    var mailbox = Mailbox();
    var receivePort = ReceivePort();
    var isolate = await Isolate.spawn(
        _isolateMain, (entryPoint, mailbox.asSendable, receivePort.sendPort));
    return ReusableIsolate._(isolate, mailbox, receivePort);
  }

  /// Checks out this isolate and returns a stream of messages from it.
  ///
  /// This isolate is considered "checked out" until the returned stream
  /// completes. While checked out, messages may be sent to the isolate using
  /// [send].
  ///
  /// Throws a [StateError] if this is called while the isolate is already
  /// checked out.
  Stream<Uint8List> checkOut() {
    if (_checkedOut) {
      throw StateError(
          "Can't call ResuableIsolate.checkOut until the previous stream has "
          "completed.");
    }
    _checkedOut = true;

    var controller = StreamController<Uint8List>(sync: true);

    _subscription.onData((message) {
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

      if (category == 2) {
        // Parse out the compilation ID and surface the [ProtocolError] as an
        // error. This allows the [IsolateDispatcher] to notice that an error
        // has occurred and close out the underlying channel.
        var (_, buffer) = parsePacket(packet);
        controller.addError(OutboundMessage.fromBuffer(buffer).error);
        return;
      }

      controller.sink.add(packet);
      if (category == 1) {
        _checkedOut = false;
        _subscription.onData(_defaultOnData);
        _subscription.onError(null);
        controller.close();
      }
    });

    _subscription.onError(controller.addError);

    return controller.stream;
  }

  /// Sends [message] to the isolate.
  ///
  /// Throws a [StateError] if this is called while the isolate isn't checked
  /// out, or if a second message is sent before the isolate has processed the
  /// first one.
  void send(Uint8List message) {
    _mailbox.put(message);
  }

  /// Shuts down the isolate.
  void kill() {
    _isolate.kill();
    _receivePort.close();

    // If the isolate is blocking on [Mailbox.take], it won't even process a
    // kill event, so we closed the mailbox to nofity and wake it up.
    _mailbox.close();
  }
}

/// The default handler for data events from the wrapped isolate when it's not
/// checked out.
void _defaultOnData(Object? _) {
  throw StateError("Shouldn't receive a message before being checked out.");
}

void _isolateMain(
    (ReusableIsolateEntryPoint, Sendable<Mailbox>, SendPort) message) {
  var (entryPoint, sendableMailbox, sendPort) = message;
  entryPoint(sendableMailbox.materialize(), sendPort);
}
