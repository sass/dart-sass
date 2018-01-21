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
    ..addFlag('stdin', help: 'Read the stylesheet from stdin.')
    ..addOption('style',
        abbr: 's',
        help: 'Output style.',
        allowed: ['expanded', 'compressed'],
        defaultsTo: 'expanded')
    ..addFlag('color', abbr: 'c', help: 'Whether to emit terminal colors.')
    ..addFlag('trace', help: 'Print full Dart stack traces for exceptions.')
    ..addFlag('help',
        abbr: 'h', help: 'Print this usage information.', negatable: false)
    ..addFlag('version',
        help: 'Print the version of Dart Sass.', negatable: false)

    // This is used when testing to ensure that the asynchronous evaluator path
    // works the same as the synchronous one.
    ..addFlag('async', hide: true);

  ArgResults options;
  try {
    options = argParser.parse(args);
  } on FormatException catch (error) {
    _printUsage(argParser, error.message);
    exitCode = 64;
    return;
  }

  if (options['version'] as bool) {
    _loadVersion().then((version) {
      print(version);
      exitCode = 0;
    });
    return;
  }

  var stdinFlag = options['stdin'] as bool;
  if (options['help'] as bool || (options.rest.isEmpty && !stdinFlag)) {
    _printUsage(argParser, "Compile Sass to CSS.");
    exitCode = 64;
    return;
  }

  var color =
      options.wasParsed('color') ? options['color'] as bool : hasTerminal;
  var style = options['style'] == 'compressed'
      ? OutputStyle.compressed
      : OutputStyle.expanded;
  var asynchronous = options['async'] as bool;
  try {
    String css;
    if (stdinFlag) {
      css = await _compileStdin(style: style, asynchronous: asynchronous);
    } else {
      var input = options.rest.first;
      if (input == '-') {
        css = await _compileStdin(style: style, asynchronous: asynchronous);
      } else if (asynchronous) {
        css = await compileAsync(input, color: color, style: style);
      } else {
        css = compile(input, color: color, style: style);
      }
    }

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
  } on FileSystemException catch (error, stackTrace) {
    stderr
        .writeln("Error reading ${p.relative(error.path)}: ${error.message}.");

    // Error 66 indicates no input.
    exitCode = 66;

    if (options['trace'] as bool) {
      stderr.writeln();
      stderr.write(new Trace.from(stackTrace).terse.toString());
      stderr.flush();
    }
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

/// Compiles Sass from standard input and returns the result.
Future<String> _compileStdin(
    {bool color: false, OutputStyle style, bool asynchronous: false}) async {
  var text = await readStdin();
  var importer = new FilesystemImporter('.');
  if (asynchronous) {
    return await compileStringAsync(text,
        color: color, style: style, importer: importer);
  } else {
    return compileString(text, color: color, style: style, importer: importer);
  }
}

/// Print the usage information for Sass, with [message] as a header.
void _printUsage(ArgParser parser, String message) {
  print("$message\n");
  print("Usage: dart-sass <input>\n");
  print(parser.usage);
}
