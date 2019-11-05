// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';

import 'utils.dart';

main(List<String> args) {
  pkg.addGithubTasks();
  grind(args);
}

@Task('Compile the protocol buffer definition to a Dart library.')
protobuf() async {
  Directory('build').createSync(recursive: true);

  // Make sure we use the version of protoc_plugin defined by our pubspec,
  // rather than whatever version the developer might have globally installed.
  log("Writing protoc-gen-dart");
  if (Platform.isWindows) {
    File('build/protoc-gen-dart.bat').writeAsStringSync('''
@echo off
pub run protoc_plugin %*
''');
  } else {
    File('build/protoc-gen-dart')
        .writeAsStringSync('pub run protoc_plugin "\$@"');
    runProcess('chmod', arguments: ['a+x', 'build/protoc-gen-dart']);
  }

  await cloneOrPull("git://github.com/sass/embedded-protocol");
  await runAsync("protoc",
      arguments: [
        "-Ibuild/embedded-protocol",
        "embedded_sass.proto",
        "--dart_out=lib/src/"
      ],
      runOptions: RunOptions(environment: {
        "PATH": 'build' +
            (Platform.isWindows ? ";" : ":") +
            Platform.environment["PATH"]
      }));
}
