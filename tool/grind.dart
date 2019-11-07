// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:grinder/grinder.dart';

import 'grind/npm.dart';
import 'grind/standalone.dart';
import 'grind/synchronize.dart';

export 'grind/bazel.dart';
export 'grind/benchmark.dart';
export 'grind/chocolatey.dart';
export 'grind/github.dart';
export 'grind/homebrew.dart';
export 'grind/npm.dart';
export 'grind/sanity_check.dart';
export 'grind/standalone.dart';
export 'grind/synchronize.dart';

void main(List<String> args) => grind(args);

@DefaultTask('Compile async code and reformat.')
@Depends(format, synchronize)
void all() {}

@Task('Run the Dart formatter.')
void format() {
  Pub.run('dart_style', script: 'format', arguments: [
    '--overwrite',
    '--fix',
    for (var dir in existingSourceDirs) dir.path
  ]);
}

@Task('Installs dependencies from npm.')
void npmInstall() => run("npm", arguments: ["install"]);

@Task('Runs the tasks that are required for running tests.')
@Depends(format, synchronize, npmPackage, npmInstall, appSnapshot)
void beforeTest() {}
