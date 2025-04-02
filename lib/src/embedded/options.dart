// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import '../io.dart';
import 'worker_dispatcher.dart';

/// Returns true if should start embedded compiler,
/// and false if should exit.
bool parseOptions(List<String> args) {
  switch (args) {
    case ["--version", ...]:
      var response = WorkerDispatcher.versionResponse();
      response.id = 0;
      safePrint(JsonEncoder.withIndent("  ").convert(response.toProto3Json()));
      return false;

    case [_, ...]:
      printError(
          "sass --embedded is not intended to be executed with additional "
          "arguments.\n"
          "See https://github.com/sass/dart-sass#embedded-dart-sass for "
          "details.");
      // USAGE error from https://bit.ly/2poTt90
      exitCode = 64;
      return false;
  }

  return true;
}
