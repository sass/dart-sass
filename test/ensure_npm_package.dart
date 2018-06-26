// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'package:sass/src/io.dart';

hybridMain(StreamChannel channel) async {
  if (!new Directory("build/npm").existsSync()) {
    throw "NPM package is not built. Run pub run grinder npm-package.";
  }

  var lastModified = new File("build/npm/package.json").lastModifiedSync();
  var entriesToCheck = new Directory("lib").listSync(recursive: true).toList();

  // If we have a dependency override, "pub run" will touch the lockfile to mark
  // it as newer than the pubspec, which makes it unsuitable to use for
  // freshness checking.
  if (new File("pubspec.yaml")
      .readAsStringSync()
      .contains("dependency_overrides")) {
    entriesToCheck.add(new File("pubspec.yaml"));
  } else {
    entriesToCheck.add(new File("pubspec.lock"));
  }

  for (var entry in entriesToCheck) {
    if (entry is File) {
      var entryLastModified = entry.lastModifiedSync();
      if (lastModified.isBefore(entryLastModified)) {
        throw "${entry.path} was modified after NPM package was generated.\n"
            "Run pub run grinder before-test.";
      }
    }
  }

  channel.sink.close();
}

/// Ensures that the NPM package is compiled and up-to-date.
///
/// This is safe to call even outside the Dart VM.
Future ensureNpmPackage() async {
  // spawnHybridUri() doesn't currently work on Windows and Node due to busted
  // path handling in the SDK.
  if (isNode && isWindows) return;

  var channel = spawnHybridUri("/test/ensure_npm_package.dart");
  await channel.stream.toList();
}
