// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// The version of Dart Sass.
final String version =
    loadYaml(File('pubspec.yaml').readAsStringSync())['version'] as String;

/// The version of the current Dart executable.
final Version dartVersion = Version.parse(Platform.version.split(" ").first);

/// Options for [run] that tell Git to commit using SassBot's name and email.
final sassBotEnvironment = RunOptions(environment: {
  "GIT_AUTHOR_NAME": "Sass Bot",
  "GIT_AUTHOR_EMAIL": "sass.bot.beep.boop@gmail.com",
  "GIT_COMMITTER_NAME": "Sass Bot",
  "GIT_COMMITTER_EMAIL": "sass.bot.beep.boop@gmail.com"
});

/// Whether we're using a dev Dart SDK.
bool get isDevSdk => dartVersion.isPreRelease;

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

/// Creates an [ArchiveFile] with the given [path] and [data].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile fileFromBytes(String path, List<int> data,
        {bool executable = false}) =>
    ArchiveFile(path, data.length, data)
      ..mode = executable ? 495 : 428
      ..lastModTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Creates a UTF-8-encoded [ArchiveFile] with the given [path] and [contents].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile fileFromString(String path, String contents,
        {bool executable = false}) =>
    fileFromBytes(path, utf8.encode(contents), executable: executable);

/// Creates an [ArchiveFile] at the archive path [target] from the local file at
/// [source].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile file(String target, String source, {bool executable = false}) =>
    fileFromBytes(target, File(source).readAsBytesSync(),
        executable: executable);

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
