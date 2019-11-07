// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

import 'utils.dart';

/// A regular expression for locating the URL and SHA256 hash of the Sass
/// archive in the `homebrew-sass` formula.
final _homebrewRegExp = RegExp(r'\n( *)url "[^"]+"'
    r'\n *sha256 "[^"]+"');

@Task('Update the Homebrew formula for the current version.')
Future<void> updateHomebrew() async {
  ensureBuild();

  var process = await Process.start("git",
      ["archive", "--prefix=dart-sass-$version/", "--format=tar.gz", version]);
  var digest = await sha256.bind(process.stdout).first;
  var stderr = await utf8.decodeStream(process.stderr);
  if ((await process.exitCode) != 0) {
    fail('git archive "$version" failed:\n$stderr');
  }

  var repo = await cloneOrPull("https://github.com/sass/homebrew-sass.git");

  var formula = File(p.join(repo, "sass.rb"));
  log("updating ${formula.path}");
  formula.writeAsStringSync(formula.readAsStringSync().replaceFirstMapped(
      _homebrewRegExp,
      (match) => '\n${match[1]}url '
          '"https://github.com/sass/dart-sass/archive/$version.tar.gz"'
          '\n${match[1]}sha256 "$digest"'));

  run("git",
      arguments: [
        "commit",
        "--all",
        "--message",
        "Update Dart Sass to $version"
      ],
      workingDirectory: repo,
      runOptions: sassBotEnvironment);

  var username = environment('GITHUB_USER');
  var password = environment('GITHUB_AUTH');
  await runAsync("git",
      arguments: [
        "push",
        "https://$username:$password@github.com/sass/homebrew-sass.git",
        "HEAD:master"
      ],
      workingDirectory: repo);
}
