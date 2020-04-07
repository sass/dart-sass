// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.
@JS()
library worker_threads;

import 'package:js/js.dart';

@JS("worker_threads")
external WorkerThreads get worker_threads;

bool isMainThread = worker_threads?.isMainThread;
ParentPort parentPort = worker_threads?.parentPort;

@JS()
abstract class WorkerThreads {
  @JS('Worker')
  external Worker get worker;
  external bool get workerData;
  external bool get isMainThread;
  external ParentPort get parentPort;
  external const factory WorkerThreads();
}

@JS()
@anonymous
class WorkerOptions {
  external factory WorkerOptions(
      {Object env, bool eval, List<String> execArgv, Object workerData});
}

@JS()
class Worker {
  external void on(String message, Function callback);

  external const factory Worker(String fileName, WorkerOptions options);
}

@JS("parentPort")
@anonymous
abstract class ParentPort {
  external factory ParentPort();
  external void postMessage(Object message);
}
