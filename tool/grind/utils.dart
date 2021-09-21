// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

/// Options for [run] that tell Git to commit using SassBot's name and email.
final sassBotEnvironment = RunOptions(environment: {
  "GIT_AUTHOR_NAME": pkg.botName.value,
  "GIT_AUTHOR_EMAIL": pkg.botEmail.value,
  "GIT_COMMITTER_NAME": pkg.botName.value,
  "GIT_COMMITTER_EMAIL": pkg.botEmail.value
});

/// Returns the HTTP basic authentication Authorization header from the
/// environment.
String get githubAuthorization {
  var bearerToken = pkg.githubBearerToken.value;
  return bearerToken != null
      ? "Bearer $bearerToken"
      : "Basic " +
          base64.encode(utf8
              .encode(pkg.githubUser.value + ':' + pkg.githubPassword.value));
}

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
/// pointing to [ref].
///
/// Returns the path to the repository.
Future<String> cloneOrCheckout(String url, String ref) async {
  var name = p.url.basename(url);
  if (p.url.extension(name) == ".git") name = p.url.withoutExtension(name);

  var path = p.join("build", name);

  if (!Directory(p.join(path, '.git')).existsSync()) {
    delete(Directory(path));
    await runAsync("git", arguments: ["init", path]);
    await runAsync("git",
        arguments: ["config", "advice.detachedHead", "false"],
        workingDirectory: path);
    await runAsync("git",
        arguments: ["remote", "add", "origin", url], workingDirectory: path);
  } else {
    log("Updating $url");
  }

  await runAsync("git",
      arguments: ["fetch", "origin", "--depth=1", ref], workingDirectory: path);
  await runAsync("git",
      arguments: ["checkout", "FETCH_HEAD"], workingDirectory: path);
  log("");

  return path;
}
