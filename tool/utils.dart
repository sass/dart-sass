// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

/// Ensure that the repository at [url] is cloned into the build directory and
/// pointing to the latest master revision.
///
/// Returns the path to the repository.
Future<String> cloneOrPull(String url) async =>
    cloneOrCheckout(url, "origin/main");

/// Ensure that the repository at [url] is cloned into the build directory and
/// pointing to [ref].
///
/// Returns the path to the repository.
Future<String> cloneOrCheckout(String url, String ref) async {
  var name = p.url.basename(url);
  if (p.url.extension(name) == ".git") name = p.url.withoutExtension(name);

  var path = p.join("build", name);

  if (Directory(p.join(path, '.git')).existsSync()) {
    log("Updating $url");
    await runAsync("git",
        arguments: ["fetch", "origin"], workingDirectory: path);
  } else {
    delete(Directory(path));
    await runAsync("git", arguments: ["clone", url, path]);
    await runAsync("git",
        arguments: ["config", "advice.detachedHead", "false"],
        workingDirectory: path);
  }
  await runAsync("git", arguments: ["checkout", ref], workingDirectory: path);
  log("");

  return path;
}
