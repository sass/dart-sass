// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

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
      .replaceFirst(RegExp(r'"sass": "[^"]+"'), '"sass": "$version"'));

  run("yarn", workingDirectory: p.join(repo, "sass"));

  run("git",
      arguments: [
        "commit",
        "--all",
        "--message",
        "Update Dart Sass to $version"
      ],
      workingDirectory: repo,
      runOptions: sassBotEnvironment);

  run("git",
      arguments: ["tag", version],
      workingDirectory: repo,
      runOptions: sassBotEnvironment);

  var username = environment('GITHUB_USER');
  var password = environment('GITHUB_AUTH');
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
