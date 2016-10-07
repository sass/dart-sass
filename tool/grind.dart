// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:isolate';

import 'package:grinder/grinder.dart';
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:yaml/yaml.dart';

main(args) => grind(args);

@DefaultTask('Run the Dart formatter.')
format() {
  Pub.run('dart_style',
      script: 'format',
      arguments: ['--overwrite']
        ..addAll(existingSourceDirs.map((dir) => dir.path)));
}

@Task('Build Dart snapshot.')
snapshot() {
  _ensureBuild();
  Dart.run('bin/sass.dart', vmArgs: ['--snapshot=build/sass.dart.snapshot']);
}

@Task('Compile to JS.')
js() {
  _ensureBuild();
  var destination = new File('build/sass.dart.js');
  Dart2js.compile(new File('bin/sass.dart'),
      outFile: destination,
      extraArgs: ['-Dnode=true', '-Dversion=${_loadVersion()}']);
  var text = destination.readAsStringSync();
  destination.writeAsStringSync("${preamble.getPreamble()}\n$text");
}

/// Ensure that the `build/` directory exists.
void _ensureBuild() {
  new Directory('build').createSync(recursive: true);
}

/// Loads the version number from pubspec.yaml.
String _loadVersion() =>
    loadYaml(new File('pubspec.yaml').readAsStringSync())['version'];
