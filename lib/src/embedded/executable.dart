// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

import '../../sass.dart';
import 'dispatcher.dart';
import 'embedded_sass.pb.dart' hide OutputStyle;
import 'importer/file.dart';
import 'importer/host.dart';
import 'isolate_dispatcher.dart';
import 'util/length_delimited_transformer.dart';

void main(List<String> args) {
  if (args.isNotEmpty) {
    if (args.first == "--version") {
      var response = IsolateDispatcher.versionResponse();
      response.id = 0;
      stdout.writeln(
          JsonEncoder.withIndent("  ").convert(response.toProto3Json()));
      return;
    }

    stderr.writeln(
        "sass --embedded is not intended to be executed with additional "
        "arguments.\n"
        "See https://github.com/sass/dart-sass#embedded-dart-sass for "
        "details.");
    // USAGE error from https://bit.ly/2poTt90
    exitCode = 64;
    return;
  }

  IsolateDispatcher(
      StreamChannel.withGuarantees(stdin, stdout, allowSinkErrors: false)
          .transform(lengthDelimited))
        .listen();
}
