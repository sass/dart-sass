// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.
@JS()
library worker_threads;

import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS()
external Object _requireWorkerThreads(String path);

final workers = _requireWorkerThreads("worker_threads");

@JS()
external Object get workerData;

@JS()
external bool get isMainThread;

@JS()
@anonymous
class WorkerOptions {
  external factory WorkerOptions(
      {List<Object> argv,
      Object env,
      bool eval,
      List<String> execArgv,
      Object workerData});
}

@JS()
class Worker {
  external void on(String message, Function callback);

  external const factory Worker(fileName, WorkerOptions options);
}

@JS()
@anonymous
class PortOptions {
  external List get transferList;
  external factory PortOptions({List<Object> transferList = const []});
}

@JS()
external ParentPort get parentPort;

@JS()
class ParentPort {
  external static void postMessage(Object message, PortOptions options);
}
