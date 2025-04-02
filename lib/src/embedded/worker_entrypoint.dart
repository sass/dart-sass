// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:isolate' show SendPort;

import 'compilation_dispatcher.dart';
import 'sync_receive_port.dart';

void workerEntryPoint(SyncReceivePort receivePort, SendPort sendPort) {
  CompilationDispatcher(receivePort, sendPort).listen();
}
