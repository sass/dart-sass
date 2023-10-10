// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:cli_pkg/js.dart';
import 'package:sass/src/io.dart';

/// Ensures that the NPM package is compiled and up-to-date.
///
/// This is safe to call even outside the Dart VM.
Future<void> ensureNpmPackage() async {
  // spawnHybridUri() doesn't currently work on Windows and Node due to busted
  // path handling in the SDK.
  if (isNodeJs && isWindows) return;

  var channel = spawnHybridCode("""
    import 'package:cli_pkg/testing.dart' as pkg;
    import 'package:stream_channel/stream_channel.dart';

    void hybridMain(StreamChannel<Object?> channel) async {
      pkg.ensureExecutableUpToDate("sass", node: true);
      channel.sink.close();
    }
  """);
  await channel.stream.toList();
}
