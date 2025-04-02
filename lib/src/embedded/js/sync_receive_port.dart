// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';
import 'dart:typed_data';

import '../sync_receive_port.dart';
import 'isolate.dart';
import 'js.dart';
import 'sync_message_port.dart';
import 'worker_threads.dart';

final class JSSyncReceivePort implements SyncReceivePort {
  final SyncMessagePort _port;

  JSSyncReceivePort(MessagePort port) : _port = SyncMessagePort(port);

  Uint8List receive() {
    return (_port.receiveMessage()! as JSUint8Array).toDart;
  }
}

final class JSSendPort implements SendPort {
  final MessagePort _port;

  JSSendPort(this._port);

  void send(Object? message) {
    var array = (message! as Uint8List).toJS;
    _port.postMessage(array, [array.buffer].toJS);
  }
}
