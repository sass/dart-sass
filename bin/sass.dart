// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as term_glyph;

import 'package:sass/src/exception.dart';
import 'package:sass/src/executable/compile_stylesheet.dart';
import 'package:sass/src/executable/options.dart';
import 'package:sass/src/executable/repl.dart';
import 'package:sass/src/executable/watch.dart';
import 'package:sass/src/import_cache.dart';
import 'package:sass/src/io.dart';
import 'package:sass/src/logger/deprecation_handling.dart';
import 'package:sass/src/stylesheet_graph.dart';
import 'package:sass/src/utils.dart';
import 'package:sass/src/embedded/executable.dart'
    // Never load the embedded protocol when compiling to JS.
    if (dart.library.js) 'package:sass/src/embedded/unavailable.dart'
    as embedded;

Future<void> main(List<String> args) async {
  var printedError = false;

  // Prints [error] to stderr, along with a preceding newline if anything else
  // has been printed to stderr.
  //
  // If [trace] is passed, its terse representation is printed after the error.
  void printError(String error, StackTrace? stackTrace) {
    if (printedError) stderr.writeln();
    printedError = true;
    stderr.writeln(error);

    if (stackTrace != null) {
      stderr.writeln();
      stderr.writeln(Trace.from(stackTrace).terse.toString().trimRight());
    }
  }

  if (args.length > 0 && args[0] == '--embedded') {
    embedded.main(args.sublist(1));
    return;
  }

  ExecutableOptions? options;
  try {
    options = ExecutableOptions.parse(args);
    term_glyph.ascii = !options.unicode;

    if (options.version) {
      print(await _loadVersion());
      exitCode = 0;
      return;
    }

    if (options.interactive) {
      await repl(options);
      return;
    }

    var graph = StylesheetGraph(ImportCache(
        loadPaths: options.loadPaths,
        // This logger is only used for handling fatal/future deprecations
        // during parsing, and is re-used across parses, so we don't want to
        // limit repetition. A separate DeprecationHandlingLogger is created for
        // each compilation, which will limit repetition if verbose is not
        // passed in addition to handling fatal/future deprecations.
        logger: DeprecationHandlingLogger(options.logger,
            fatalDeprecations: options.fatalDeprecations,
            futureDeprecations: options.futureDeprecations,
            limitRepetition: false)));
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
            if (destination != null &&
                // dart-lang/sdk#45348
                !options!.emitErrorCss) {
              deleteFile(destination);
            }
          } on FileSystemException {
            // If the file doesn't exist, that's fine.
          }
        }();

        printError(error.toString(color: options.color),
            options.trace ? getTrace(error) ?? stackTrace : null);

        // Exit code 65 indicates invalid data per
        // https://www.freebsd.org/cgi/man.cgi?query=sysexits.
        //
        // We let exitCode 66 take precedence for deterministic behavior.
        if (exitCode != 66) exitCode = 65;
        if (options.stopOnError) return;
      } on FileSystemException catch (error, stackTrace) {
        var path = error.path;
        printError(
            path == null
                ? error.message
                : "Error reading ${p.relative(path)}: ${error.message}.",
            options.trace ? getTrace(error) ?? stackTrace : null);

        // Error 66 indicates no input.
        exitCode = 66;
        if (options.stopOnError) return;
      }
    }
  } on UsageException catch (error) {
    print("${error.message}\n");
    print("Usage: sass <input.scss> [output.css]\n"
        "       sass <input.scss>:<output.css> <input/>:<output/> <dir/>\n");
    print(ExecutableOptions.usage);
    exitCode = 64;
  } catch (error, stackTrace) {
    var buffer = StringBuffer();
    if (options != null && options.color) buffer.write('\u001b[31m\u001b[1m');
    buffer.write('Unexpected exception:');
    if (options != null && options.color) buffer.write('\u001b[0m');
    buffer.writeln();
    buffer.writeln(error);

    printError(buffer.toString(), getTrace(error) ?? stackTrace);
    exitCode = 255;
  }
}

/// Loads and returns the current version of Sass.
Future<String> _loadVersion() async {
  if (const bool.hasEnvironment('version')) {
    var version = const String.fromEnvironment('version');
    if (const bool.fromEnvironment('node')) {
      version += " compiled with dart2js "
          "${const String.fromEnvironment('dart-version')}";
    }
    return version;
  }

  var libDir =
      p.fromUri(await Isolate.resolvePackageUri(Uri.parse('package:sass/')));
  var pubspec = readFile(p.join(libDir, '..', 'pubspec.yaml'));
  return pubspec
      .split("\n")
      .firstWhere((line) => line.startsWith('version: '))
      .split(" ")
      .last;
}
