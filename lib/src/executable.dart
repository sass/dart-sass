// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:stack_trace/stack_trace.dart';

import '../sass.dart';
import 'exception.dart';
import 'io.dart';
import 'util/path.dart';

main(List<String> args) async {
  var argParser = new ArgParser(allowTrailingOptions: true)
    ..addOption('precision', hide: true)
    ..addOption('style',
        abbr: 's',
        help: 'Output style.',
        allowed: ['expanded'],
        defaultsTo: 'expanded')
    ..addFlag('color', abbr: 'c', help: 'Whether to emit terminal colors.')
    ..addFlag('trace', help: 'Print full Dart stack traces for exceptions.')
    ..addFlag('help',
        abbr: 'h', help: 'Print this usage information.', negatable: false)
    ..addFlag('version',
        help: 'Print the version of Dart Sass.', negatable: false);
  var options = argParser.parse(args);

  if (options['version'] as bool) {
    _loadVersion().then((version) {
      print(version);
      exitCode = 0;
    });
    return;
  }

  if (options['help'] as bool || options.rest.isEmpty) {
    print("Compile Sass to CSS.\n");
    print("Usage: dart-sass <input>\n");
    print(argParser.usage);
    exitCode = 64;
    return;
  }

  var color = (options['color'] as bool) ?? hasTerminal;
  try {
    var css = compile(options.rest.first, color: color);
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
    exitCode = 65;
  } catch (error, stackTrace) {
    if (color) stderr.write('\u001b[31m\u001b[1m');
    stderr.write('Unexpected exception:');
    if (color) stderr.write('\u001b[0m');
    stderr.writeln();

    stderr.writeln(error);
    stderr.writeln();
    stderr.write(new Trace.from(stackTrace).terse.toString());
    await stderr.flush();
    exitCode = 255;
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
