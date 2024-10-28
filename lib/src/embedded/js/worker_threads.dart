// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

@JS('worker_threads.isMainThread')
external bool get isMainThread;

@JS('worker_threads.workerData')
external JSAny? get workerData;

@JS('worker_threads.Worker')
extension type Worker._(JSObject _) implements JSObject {
  external Worker(String filename, WorkerOptions options);
  external void once(String type, JSFunction listener);
  external void terminate();
}

@JS()
extension type WorkerOptions._(JSObject _) implements JSObject {
  external WorkerOptions(
      {JSArray<JSAny?> argv,
      JSObject env,
      bool eval,
      JSArray<JSString> execArgv,
      bool stdin,
      bool stdout,
      bool stderr,
      JSAny workerData,
      bool trackUnmanagedFds,
      JSArray<JSAny> transferList,
      ResourceLimits resourceLimits});
  external JSArray<JSAny?> get argv;
  external JSObject get env;
  external bool get eval;
  external JSArray<JSString> get execArgv;
  external bool get stdin;
  external bool get stdout;
  external bool get stderr;
  external JSAny get workerData;
  external bool get trackUnmanagedFds;
  external JSArray<JSAny> get transferList;
  external ResourceLimits get resourceLimits;
}

@JS()
extension type ResourceLimits._(JSObject _) implements JSObject {
  external ResourceLimits(
      {int maxYoungGenerationSizeMb,
      int maxOldGenerationSizeMb,
      int codeRangeSizeMb,
      int stackSizeMb});
  external int get maxYoungGenerationSizeMb;
  external int get maxOldGenerationSizeMb;
  external int get codeRangeSizeMb;
  external int get stackSizeMb;
}

@JS()
extension type MessageChannel._(JSObject _) implements JSObject {
  external MessagePort get port1;
  external MessagePort get port2;
}

@JS()
extension type MessagePort._(JSObject _) implements JSObject {
  external void postMessage(JSAny? value, [JSArray<JSAny> transferList]);
  external void on(String type, JSFunction listener);
  external void close();
}
