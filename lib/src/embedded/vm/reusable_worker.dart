// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';
import 'package:native_synchronization/sendable.dart';

import '../sync_receive_port.dart';
import '../compilation_dispatcher.dart';

class ReusableWorker {
  /// The wrapped isolate.
  final Isolate _isolate;

  /// The mailbox used to send messages to this isolate.
  final Mailbox _mailbox;

  /// The [ReceivePort] that receives messages from the wrapped isolate.
  final ReceivePort _receivePort;

  /// The subscription to [_receivePort].
  final StreamSubscription<dynamic> _subscription;

  /// Whether the current isolate has been borrowed.
  bool _borrowed = false;

  ReusableWorker._(
    this._isolate,
    this._mailbox,
    this._receivePort, {
    Function? onError,
  }) : _subscription = _receivePort.listen(_defaultOnData, onError: onError);

  /// Spawns a [ReusableWorker].
  static Future<ReusableWorker> spawn({
    Function? onError,
  }) async {
    var mailbox = Mailbox();
    var receivePort = ReceivePort();
    var isolate = await Isolate.spawn(_isolateMain, (
      mailbox.asSendable,
      receivePort.sendPort,
    ));
    return ReusableWorker._(isolate, mailbox, receivePort, onError: onError);
  }

  /// Subscribe to messages from [_receivePort].
  void borrow(void onData(dynamic event)?) {
    if (_borrowed) {
      throw StateError('ReusableWorker has already been borrowed.');
    }
    _borrowed = true;
    _subscription.onData(onData);
  }

  /// Unsubscribe to messages from [_receivePort].
  void release() {
    if (!_borrowed) {
      throw StateError('ReusableWorker has not been borrowed.');
    }
    _borrowed = false;
    _subscription.onData(_defaultOnData);
  }

  /// Sends [message] to the isolate.
  ///
  /// Throws a [StateError] if this is called while the isolate isn't borrowed,
  /// or if a second message is sent before the isolate has processed the first
  /// one.
  void send(Uint8List message) {
    if (!_borrowed) {
      throw StateError('Cannot send a message before being borrowed.');
    }
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

/// The default handler for data events from the wrapped isolate when it's not
/// borrowed.
void _defaultOnData(dynamic _) {
  throw StateError("Shouldn't receive a message before being borrowed.");
}

void _isolateMain((Sendable<Mailbox>, SendPort) message) {
  var (sendableMailbox, sendPort) = message;
  CompilationDispatcher(
          MailboxSyncReceivePort(sendableMailbox.materialize()), sendPort)
      .listen();
}
