// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

/// Options for [run] that tell Git to commit using SassBot's name and email.
final sassBotEnvironment = RunOptions(environment: {
  "GIT_AUTHOR_NAME": pkg.botName,
  "GIT_AUTHOR_EMAIL": pkg.botEmail,
  "GIT_COMMITTER_NAME": pkg.botName,
  "GIT_COMMITTER_EMAIL": pkg.botEmail
});

/// Ensure that the `build/` directory exists.
void ensureBuild() {
  Directory('build').createSync(recursive: true);
}

/// Returns the environment variable named [name], or throws an exception if it
/// can't be found.
String environment(String name) {
  var value = Platform.environment[name];
  if (value == null) fail("Required environment variable $name not found.");
  return value;
}

/// Ensure that the repository at [url] is cloned into the build directory and
/// pointing to the latest master revision.
///
/// Returns the path to the repository.
Future<String> cloneOrPull(String url) async =>
    cloneOrCheckout(url, "origin/master");

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
