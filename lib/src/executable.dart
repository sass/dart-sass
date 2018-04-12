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
    ..addFlag('indented', help: 'Use the indented syntax for input from stdin.')
    ..addMultiOption('load-path',
        abbr: 'I',
        valueHelp: 'PATH',
        help: 'A path to use when resolving imports.\n'
            'May be passed multiple times.',
        splitCommas: false)
    ..addOption('style',
        abbr: 's',
        valueHelp: 'NAME',
        help: 'Output style.',
        allowed: ['expanded', 'compressed'],
        defaultsTo: 'expanded')
    ..addFlag('color', abbr: 'c', help: 'Whether to emit terminal colors.')
    ..addFlag('quiet', abbr: 'q', help: "Don't print warnings.")
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
  if (options['help'] as bool ||
      (stdinFlag
          ? options.rest.length > 1
          : options.rest.isEmpty || options.rest.length > 2)) {
    _printUsage(argParser, "Compile Sass to CSS.");
    exitCode = 64;
    return;
  }

  var indented =
      options.wasParsed('indented') ? options['indented'] as bool : null;
  var color =
      options.wasParsed('color') ? options['color'] as bool : hasTerminal;
  var logger =
      options['quiet'] as bool ? Logger.quiet : new Logger.stderr(color: color);
  var style = options['style'] == 'compressed'
      ? OutputStyle.compressed
      : OutputStyle.expanded;
  var loadPaths = options['load-path'] as List<String>;
  var asynchronous = options['async'] as bool;
  try {
    String css;
    String destination;
    if (stdinFlag) {
      if (options.rest.isNotEmpty) destination = options.rest.first;
      css = await _compileStdin(
          indented: indented,
          logger: logger,
          style: style,
          loadPaths: loadPaths,
          asynchronous: asynchronous);
    } else {
      var source = options.rest.first;
      if (options.rest.length > 1) destination = options.rest.last;
      if (source == '-') {
        css = await _compileStdin(
            indented: indented,
            logger: logger,
            style: style,
            loadPaths: loadPaths,
            asynchronous: asynchronous);
      } else if (asynchronous) {
        css = await compileAsync(source,
            logger: logger, style: style, loadPaths: loadPaths);
      } else {
        css =
            compile(source, logger: logger, style: style, loadPaths: loadPaths);
      }
    }

    if (destination != null) {
      ensureDir(p.dirname(destination));
      writeFile(destination, css + "\n");
    } else if (css.isNotEmpty) {
      print(css);
    }
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
    {bool indented,
    Logger logger,
    OutputStyle style,
    List<String> loadPaths,
    bool asynchronous: false}) async {
  var text = await readStdin();
  var importer = new FilesystemImporter('.');
  if (asynchronous) {
    return await compileStringAsync(text,
        indented: indented,
        logger: logger,
        style: style,
        importer: importer,
        loadPaths: loadPaths);
  } else {
    return compileString(text,
        indented: indented,
        logger: logger,
        style: style,
        importer: importer,
        loadPaths: loadPaths);
  }
}

/// Print the usage information for Sass, with [message] as a header.
void _printUsage(ArgParser parser, String message) {
  print("$message\n");
  print("Usage: sass <input> [output]\n");
  print(parser.usage);
}
