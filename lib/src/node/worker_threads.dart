// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

class WorkerOptions extends Object {
}

@JS("worker_threads")
class Worker {
  external Worker on(String message, Function callback);

  external factory Worker(String filename, WorkerOptions options);
}

@JS("worker_threads")
class ParentPort {
  external ParentPort postMessage(Object value,
      {List transferList = const []});
}

