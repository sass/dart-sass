// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:native_synchronization/sendable.dart';
import 'package:pool/pool.dart';

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
  ReceivePort get receivePort => _receivePort;

  /// The [PoolResource] used to track whether this isolate is being used.
  PoolResource? _resource;

  ReusableIsolate._(this._isolate, this._mailbox, this._receivePort);

  /// Spawns a [ReusableIsolate] that runs the given [entryPoint].
  static Future<ReusableIsolate> spawn(
      ReusableIsolateEntryPoint entryPoint) async {
    var mailbox = Mailbox();
    var receivePort = ReceivePort();
    var isolate = await Isolate.spawn(
        _isolateMain, (entryPoint, mailbox.asSendable, receivePort.sendPort));
    return ReusableIsolate._(isolate, mailbox, receivePort);
  }

  /// Whether this isolate is in use
  bool get borrowed => _resource != null;

  /// Request this isolate as part of a pool and mark it as in use.
  void borrow(PoolResource resource) {
    assert(!borrowed, 'ReusableIsolate has already been borrowed.');
    _resource = resource;
  }

  /// Release this isolate from the pool.
  void release() {
    assert(borrowed, 'ReusableIsolate has not been borrowed.');
    _resource!.release();
    _resource = null;
  }

  /// Sends [message] to the isolate.
  ///
  /// Throws a [StateError] if this is called while the isolate isn't checked
  /// out, or if a second message is sent before the isolate has processed the
  /// first one.
  void send(Uint8List message) {
    assert(borrowed, 'Cannot send a message before being borrowed');
    _mailbox.put(message);
  }

  /// Shuts down the isolate.
  void kill() {
    // If the isolate is blocking on [Mailbox.take], it won't even process a
    // kill event, so we closed the mailbox to nofity and wake it up.
    _mailbox.close();
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}

void _isolateMain(
    (ReusableIsolateEntryPoint, Sendable<Mailbox>, SendPort) message) {
  var (entryPoint, sendableMailbox, sendPort) = message;
  entryPoint(sendableMailbox.materialize(), sendPort);
}
