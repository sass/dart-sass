// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'js.dart';
import 'sync_message_port.dart';
import 'worker_threads.dart';

/// The entrypoint for a [ReusableWorker].
///
/// This must return a Record of filename and argv for creating the Worker.
typedef ReusableWorkerEntryPoint = (String, JSArray<JSAny?>) Function();

class ReusableWorker {
  /// The worker.
  final Worker _worker;

  /// The [MessagePort] used to receive messages to the [Worker].
  final MessagePort _receivePort;

  /// The [SyncMessagePort] used to send to the [Worker].
  final SyncMessagePort _sendPort;

  /// The subscription to [_receivePort].
  final StreamSubscription<dynamic> _subscription;

  /// Whether the current worker has been borrowed.
  bool _borrowed = false;

  ReusableWorker._(
      this._worker, this._sendPort, this._receivePort, this._subscription);

  /// Spawns a [ReusableWorker] that runs the the entrypoint script.
  static Future<ReusableWorker> spawn(ReusableWorkerEntryPoint entryPoint,
      {Function? onError}) async {
    var (filename, argv) = entryPoint();
    var channel = SyncMessagePort.createChannel();
    var worker = Worker(
        filename,
        WorkerOptions(
            workerData: channel.port2,
            transferList: [channel.port2].toJS,
            argv: argv));
    var controller = StreamController<dynamic>(sync: true);
    var sendPort = SyncMessagePort(channel.port1);
    var receivePort = channel.port1;
    receivePort.on(
        'message',
        ((JSUint8Array buffer) {
          controller.add(buffer.toDart);
        }).toJS);
    return ReusableWorker._(worker, sendPort, receivePort,
        controller.stream.listen(_defaultOnData));
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

  /// Sends [message] to the worker.
  ///
  /// Throws a [StateError] if this is called while the worker isn't borrowed,
  /// or if a second message is sent before the worker has processed the first
  /// one.
  void send(Uint8List message) {
    if (!_borrowed) {
      throw StateError('Cannot send a message before being borrowed.');
    }
    var array = message.toJS;
    _sendPort.postMessage(array, [array.buffer].toJS);
  }

  /// Shuts down the worker.
  void kill() {
    _sendPort.close();
    _worker.terminate();
    _receivePort.close();
  }
}

/// The default handler for data events from the wrapped worker when it's not
/// borrowed.
void _defaultOnData(dynamic _) {
  throw StateError("Shouldn't receive a message before being borrowed.");
}
