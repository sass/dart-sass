// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'package:sass/src/io.dart';

import 'io.dart';

void hybridMain(StreamChannel<Object> channel) async {
  ensureUpToDate("build/npm/sass.dart.js", "pub run grinder npm-package");
  channel.sink.close();
}

/// Ensures that the NPM package is compiled and up-to-date.
///
/// This is safe to call even outside the Dart VM.
Future<void> ensureNpmPackage() async {
  // spawnHybridUri() doesn't currently work on Windows and Node due to busted
  // path handling in the SDK.
  if (isNode && isWindows) return;

  var channel = spawnHybridUri("/test/ensure_npm_package.dart");
  await channel.stream.toList();
}
