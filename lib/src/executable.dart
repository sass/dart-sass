// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:path/path.dart' as p;

import '../sass.dart';
import 'exception.dart';
import 'io.dart';

void main(List<String> args) {
  var argParser = new ArgParser(allowTrailingOptions: true)
    ..addOption('precision', hide: true)
    ..addOption('style',
        abbr: 's',
        help: 'Output style.',
        allowed: ['expanded'],
        defaultsTo: 'expanded')
    ..addFlag('color',
        abbr: 'c', help: 'Whether to emit terminal colors.', defaultsTo: true)
    ..addFlag('trace', help: 'Print full Dart stack traces for exceptions.')
    ..addFlag('help',
        abbr: 'h', help: 'Print this usage information.', negatable: false)
    ..addFlag('version',
        help: 'Print the version of Dart Sass.', negatable: false);
  var options = argParser.parse(args);

  if (options['version']) {
    _loadVersion().then((version) {
      print(version);
      exit(0);
    });
    return;
  }

  if (options['help'] || options.rest.isEmpty) {
    print("Compile Sass to CSS.\n");
    print("Usage: sass <input>\n");
    print(argParser.usage);
    exit(64);
  }

  try {
    var css = render(options.rest.first);
    if (css.isNotEmpty) print(css);
  } on SassException catch (error, stackTrace) {
    stderr.writeln(error.toString(color: options['color']));

    if (options['trace']) {
      stderr.writeln();
      stderr.write(new Trace.from(stackTrace).toString());
      stderr.flush();
    }

    exit(1);
  }
}

/// Loads and returns the current version of Sass.
Future<String> _loadVersion() async {
  var version = const String.fromEnvironment('version');
  if (version != null) return version;

  var libDir =
      p.fromUri(await Isolate.resolvePackageUri(Uri.parse('package:sass/')));
  var pubspec = readFile(p.join(libDir, '..', 'pubspec.yaml'));
  return pubspec
      .split("\n")
      .firstWhere((line) => line.startsWith('version: '))
      .split(" ")
      .last;
}
