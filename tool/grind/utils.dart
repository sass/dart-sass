// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

// Work around the lack of google/grinder.dart#402.
import 'package:grinder/src/singleton.dart';

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
  if (Platform.environment[name] case var value?) return value;
  fail("Required environment variable $name not found.");
}

/// Ensure that the repository at [url] is cloned into the build directory and
/// pointing to [ref].
///
/// If [name] is passed, it's used as the basename of the directory for the
/// repo. Otherwise, [url]'s basename is used.
///
/// Returns the path to the repository.
String cloneOrCheckout(String url, String ref, {String? name}) {
  if (name == null) {
    name = p.url.basename(url);
    if (p.url.extension(name) == ".git") name = p.url.withoutExtension(name);
  }

  var path = p.join("build", name);

  if (!Directory(p.join(path, '.git')).existsSync()) {
    delete(Directory(path));
    run("git", arguments: ["init", path]);
    run("git",
        arguments: ["config", "advice.detachedHead", "false"],
        workingDirectory: path);
    run("git",
        arguments: ["remote", "add", "origin", url], workingDirectory: path);
  } else {
    log("Updating $url");
  }

  run("git",
      arguments: ["fetch", "origin", "--depth=1", ref], workingDirectory: path);
  run("git", arguments: ["checkout", "FETCH_HEAD"], workingDirectory: path);
  log("");

  return path;
}

/// Registers [callback] to run after the task named [taskName].
///
/// This must be called after the base [taskName] is registered.
void afterTask(String taskName, FutureOr<void> callback()) {
  // This takes advantage of the fact that Grinder's task list is mutable to
  // override the existing task with our new one.
  var index = grinder.tasks.indexWhere((task) => task.name == taskName);
  if (index == -1) fail("There is no task named $taskName.");

  var oldTask = grinder.tasks[index];
  grinder.tasks[index] = GrinderTask(taskName,
      description: oldTask.description,
      depends: oldTask.depends, taskFunction: (TaskArgs args) async {
    await oldTask.execute(context, args);
    await callback();
  });
}
