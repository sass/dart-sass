// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

import 'utils.dart';

@Task('Update the Bazel rules for the current version.')
Future<void> updateBazel() async {
  ensureBuild();

  run("npm", arguments: ["install", "-g", "yarn"]);

  var repo = await cloneOrPull("https://github.com/bazelbuild/rules_sass.git");

  var packageFile = File(p.join(repo, "sass", "package.json"));
  log("updating ${packageFile.path}");
  packageFile.writeAsStringSync(packageFile
      .readAsStringSync()
      .replaceFirst(RegExp(r'"sass": "[^"]+"'), '"sass": "${pkg.version}"'));

  try {
    run("yarn", workingDirectory: p.join(repo, "sass"));
  } on ProcessException catch (error) {
    if (error.stderr.contains("Couldn't find any versions for \"sass\"")) {
      log("The new sass version doesn't seem to be available yet, waiting 30s...");
      await Future<void>.delayed(Duration(minutes: 2));
      run("yarn", workingDirectory: p.join(repo, "sass"));
    }
  }

  run("git",
      arguments: [
        "commit",
        "--all",
        "--message",
        "Update Dart Sass to ${pkg.version}"
      ],
      workingDirectory: repo,
      runOptions: sassBotEnvironment);

  run("git",
      arguments: ["tag", pkg.version.toString()],
      workingDirectory: repo,
      runOptions: sassBotEnvironment);

  var username = environment('GH_USER');
  var password = environment('GH_TOKEN');
  await runAsync("git",
      arguments: [
        "push",
        "--tags",
        "https://$username:$password@github.com/bazelbuild/rules_sass.git",
      ],
      workingDirectory: repo);
  await runAsync("git",
      arguments: [
        "push",
        "https://$username:$password@github.com/bazelbuild/rules_sass.git",
        "HEAD:master"
      ],
      workingDirectory: repo);
}
