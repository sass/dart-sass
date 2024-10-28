// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:stream_channel/stream_channel.dart';

import '../isolate_dispatcher.dart';
import '../isolate_main.dart';
import '../options.dart';
import '../util/length_delimited_transformer.dart';
import 'io.dart';
import 'sync_receive_port.dart';
import 'worker_threads.dart';

void main(List<String> args) {
  if (parseOptions(args)) {
    if (isMainThread) {
      IsolateDispatcher(StreamChannel.withGuarantees(stdin, stdout,
                  allowSinkErrors: false)
              .transform(lengthDelimited))
          .listen();
    } else {
      var port = workerData! as MessagePort;
      isolateMain(JSSyncReceivePort(port), JSSendPort(port));
    }
  }
}
