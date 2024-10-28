// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

import 'isolate_dispatcher.dart';
import 'options.dart';
import 'util/length_delimited_transformer.dart';

void main(List<String> args) {
  if (parseOptions(args)) {
    IsolateDispatcher(
            StreamChannel.withGuarantees(stdin, stdout, allowSinkErrors: false)
                .transform(lengthDelimited),
            gracefulShutdown: false)
        .listen();
  }
}
