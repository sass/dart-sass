// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import 'exception.dart';
import 'executable/compile_stylesheet.dart';
import 'executable/options.dart';
import 'executable/repl.dart';
import 'executable/watch.dart';
import 'import_cache.dart';
import 'io.dart';
import 'stylesheet_graph.dart';

main(List<String> args) async {
  var printedError = false;

  // Prints [error] to stderr, along with a preceding newline if anything else
  // has been printed to stderr.
  //
  // If [trace] is passed, its terse representation is printed after the error.
  void printError(String error, StackTrace stackTrace) {
    if (printedError) stderr.writeln();
    printedError = true;
    stderr.writeln(error);

    if (stackTrace != null) {
      stderr.writeln();
      stderr.writeln(new Trace.from(stackTrace).terse.toString().trimRight());
    }
  }

  ExecutableOptions options;
  try {
    options = new ExecutableOptions.parse(args);
    if (options.version) {
      print(await _loadVersion());
      exitCode = 0;
      return;
    }

    if (options.interactive) {
      await repl(options);
      return;
    }

    var graph = new StylesheetGraph(new ImportCache([],
        loadPaths: options.loadPaths, logger: options.logger));
    if (options.watch) {
      await watch(options, graph);
      return;
    }

    for (var source in options.sourcesToDestinations.keys) {
      var destination = options.sourcesToDestinations[source];
      try {
        await compileStylesheet(options, graph, source, destination,
            ifModified: options.update);
      } on SassException catch (error, stackTrace) {
        // This is an immediately-invoked function expression to work around
        // dart-lang/sdk#33400.
        () {
          try {
            if (destination != null) deleteFile(destination);
          } on FileSystemException {
            // If the file doesn't exist, that's fine.
          }
        }();

        printError(error.toString(color: options.color),
            options.trace ? stackTrace : null);

        // Exit code 65 indicates invalid data per
        // http://www.freebsd.org/cgi/man.cgi?query=sysexits.
        //
        // We let exitCode 66 take precedence for deterministic behavior.
        if (exitCode != 66) exitCode = 65;
        if (options.stopOnError) return;
      } on FileSystemException catch (error, stackTrace) {
        printError("Error reading ${p.relative(error.path)}: ${error.message}.",
            options.trace ? stackTrace : null);

        // Error 66 indicates no input.
        exitCode = 66;
        if (options.stopOnError) return;
      }
    }
  } on UsageException catch (error) {
    print("${error.message}\n");
    print("Usage: sass <input.scss> [output.css]\n"
        "       sass <input.scss>:<output.css> <input/>:<output/>\n");
    print(ExecutableOptions.usage);
    exitCode = 64;
  } catch (error, stackTrace) {
    var buffer = new StringBuffer();
    if (options != null && options.color) buffer.write('\u001b[31m\u001b[1m');
    buffer.write('Unexpected exception:');
    if (options != null && options.color) buffer.write('\u001b[0m');
    buffer.writeln();
    buffer.writeln(error);

    printError(buffer.toString(), stackTrace);
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
