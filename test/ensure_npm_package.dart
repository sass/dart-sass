// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

hybridMain(StreamChannel channel) async {
  if (!new Directory("build/npm").existsSync()) {
    throw "NPM package is not build. Run pub run grinder npm_package.";
  }

  var lastModified = new DateTime(0);
  var entriesToCheck = new Directory("lib").listSync(recursive: true).toList()
    ..add(new File("pubspec.lock"));
  for (var entry in entriesToCheck) {
    if (entry is File) {
      var entryLastModified = entry.lastModifiedSync();
      if (lastModified.isBefore(entryLastModified)) {
        lastModified = entryLastModified;
      }
    }
  }

  if (lastModified
      .isAfter(new File("build/npm/package.json").lastModifiedSync())) {
    throw "NPM package is out-of-date. Run pub run grinder npm_package.";
  }

  channel.sink.close();
}

/// Ensures that the NPM package is compiled and up-to-date.
///
/// This is safe to call even outside the Dart VM.k
Future ensureNpmPackage() {
  var channel = spawnHybridUri("ensure_npm_package.dart");
  return channel.stream.toList();
}
