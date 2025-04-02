// Copyright 2025 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:isolate' show SendPort;
export 'dart:isolate' show SendPort;

import 'io.dart' as io;

abstract class Isolate {
  static Never exit([SendPort? finalMessagePort, Object? message]) {
    if (message != null) {
      finalMessagePort?.send(message);
    }
    io.exit(io.exitCode) as Never;
  }
}
