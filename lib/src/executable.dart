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

  if (options['version'] as bool) {
    _loadVersion().then((version) {
      print(version);
      exit(0);
    });
    return;
  }

  if (options['help'] as bool || options.rest.isEmpty) {
    print("Compile Sass to CSS.\n");
    print("Usage: dart-sass <input>\n");
    print(argParser.usage);
    exit(64);
  }

  var color = options['color'] as bool;
  try {
    var css = render(options.rest.first, color: color);
    if (css.isNotEmpty) print(css);
  } on SassException catch (error, stackTrace) {
    stderr.writeln(error.toString(color: color));

    if (options['trace'] as bool) {
      stderr.writeln();
      stderr.write(new Trace.from(stackTrace).terse.toString());
      stderr.flush();
    }

    // Exit code 65 indicates invalid data per
    // http://www.freebsd.org/cgi/man.cgi?query=sysexits.
    exit(65);
  } catch (error, stackTrace) {
    if (color) stderr.write('\u001b[31m\u001b[1m');
    stderr.write('Unexpected exception:');
    if (color) stderr.write('\u001b[0m');
    stderr.writeln();

    stderr.writeln(error);
    stderr.writeln();
    stderr.write(new Trace.from(stackTrace).terse.toString());
    stderr.flush();
  }
}

/// Loads and returns the current version of Sass.
Future<String> _loadVersion() async {
  var version = const String.fromEnvironment('version');
  if (const bool.fromEnvironment('node')) {
    version += " compiled with dart2js "
        "${const String.fromEnvironment('dart-version')}";
  }
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
