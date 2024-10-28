// Copyright 2024 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';
import 'worker_threads.dart';

@JS('sync_message_port.SyncMessagePort')
extension type SyncMessagePort._(JSObject _) implements JSObject {
  external static MessageChannel createChannel();
  external SyncMessagePort(MessagePort port);
  external void postMessage(JSAny? value, [JSArray<JSAny> transferList]);
  external JSAny? receiveMessage();
  external void close();
}
