// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:stream_channel/stream_channel.dart';

import '../compilation_dispatcher.dart';
import '../options.dart';
import '../util/length_delimited_transformer.dart';
import '../worker_dispatcher.dart';
import 'io.dart';
import 'sync_receive_port.dart';
import 'worker_threads.dart';

void main(List<String> args) {
  if (parseOptions(args)) {
    if (isMainThread) {
      WorkerDispatcher(StreamChannel.withGuarantees(stdin, stdout,
                  allowSinkErrors: false)
              .transform(lengthDelimited))
          .listen();
    } else {
      var port = workerData! as MessagePort;
      CompilationDispatcher(JSSyncReceivePort(port), JSSendPort(port)).listen();
    }
  }
}
