// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Ensures that [path] (usually a compilation artifact) has been modified more
/// recently than all this package's source files.
///
/// If [path] isn't up-to-date, this throws an error encouraging the user to run
/// [commandToRun].
void ensureUpToDate(String path, String commandToRun) {
  // Ensure path is relative so the error messages are more readable.
  path = p.relative(path);
  if (!File(path).existsSync()) {
    throw "$path does not exist. Run $commandToRun.";
  }

  var entriesToCheck = [
    ...Directory("lib").listSync(recursive: true),

    // If we have a dependency override, "pub run" will touch the lockfile to
    // mark it as newer than the pubspec, which makes it unsuitable to use for
    // freshness checking.
    if (File("pubspec.yaml")
        .readAsStringSync()
        .contains("dependency_overrides"))
      File("pubspec.yaml")
    else
      File("pubspec.lock")
  ];

  var lastModified = File(path).lastModifiedSync();
  for (var entry in entriesToCheck) {
    if (entry is File) {
      var entryLastModified = entry.lastModifiedSync();
      if (lastModified.isBefore(entryLastModified)) {
        throw "${entry.path} was modified after ${p.prettyUri(p.toUri(path))} "
            "was generated.\n"
            "Run pub run grinder before-test.";
      }
    }
  }
}
