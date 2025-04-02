// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

import '../options.dart';
import '../util/length_delimited_transformer.dart';
import '../worker_dispatcher.dart';

void main(List<String> args) {
  if (parseOptions(args)) {
    WorkerDispatcher(
            StreamChannel.withGuarantees(stdin, stdout, allowSinkErrors: false)
                .transform(lengthDelimited),
            gracefulShutdown: false)
        .listen();
  }
}
