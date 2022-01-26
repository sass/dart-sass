// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

void main(List<String> args) {
  pkg.githubBearerToken.fn = () => Platform.environment["GH_BEARER_TOKEN"]!;

  pkg.environmentConstants.fn = () => {
        ...pkg.environmentConstants.defaultValue,
        "protocol-version":
            File('build/embedded-protocol/VERSION').readAsStringSync().trim(),
        "compiler-version": pkg.pubspec.version!.toString(),
        "implementation-version": _implementationVersion
      };

  pkg.addGithubTasks();
  grind(args);
}

/// Returns the version of Dart Sass that this package uses.
String get _implementationVersion {
  var lockfile = loadYaml(File('pubspec.lock').readAsStringSync(),
      sourceUrl: Uri(path: 'pubspec.lock'));
  return lockfile['packages']['sass']['version'] as String;
}

@Task('Compile the protocol buffer definition to a Dart library.')
Future<void> protobuf() async {
  Directory('build').createSync(recursive: true);

  // Make sure we use the version of protoc_plugin defined by our pubspec,
  // rather than whatever version the developer might have globally installed.
  log("Writing protoc-gen-dart");
  if (Platform.isWindows) {
    File('build/protoc-gen-dart.bat').writeAsStringSync('''
@echo off
dart pub run protoc_plugin %*
''');
  } else {
    File('build/protoc-gen-dart')
        .writeAsStringSync('dart pub run protoc_plugin "\$@"');
    run('chmod', arguments: ['a+x', 'build/protoc-gen-dart']);
  }

  if (Platform.environment['UPDATE_SASS_PROTOCOL'] != 'false') {
    await cloneOrPull("git://github.com/sass/embedded-protocol");
  }

  await runAsync("protoc",
      arguments: [
        "-Ibuild/embedded-protocol",
        "embedded_sass.proto",
        "--dart_out=lib/src/"
      ],
      runOptions: RunOptions(environment: {
        "PATH": 'build' +
            (Platform.isWindows ? ";" : ":") +
            Platform.environment["PATH"]!
      }));
}
