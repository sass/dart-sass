// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:bazel_worker/bazel_worker.dart';
import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as term_glyph;

import 'exception.dart';
import 'executable/compile_stylesheet.dart';
import 'executable/options.dart';
import 'executable/repl.dart';
import 'executable/watch.dart';
import 'import_cache.dart';
import 'io.dart';
import 'stylesheet_graph.dart';

main(List<String> originalArgs) async {
  var args = originalArgs.toList();
  // We assume that argument that starts with '@' is a flagfile.
  // Starlark rules that invoke this need to use args.use_param_file("@%s").
  if (args.isNotEmpty && args.last.startsWith('@')) {
    var filePath = args.removeLast().substring(1);
    args.addAll(File(filePath).readAsLinesSync());
  }

  if (args.remove('--persistent_worker')) {
    await _AsyncWorker().run();
  } else {
    _run(args);
  }
}

class _AsyncWorker extends AsyncWorkerLoop {
  Future<WorkResponse> performRequest(WorkRequest request) async {
    var output = StringBuffer();
    var exitCode = await _run(request.arguments, printFn: output.writeln);
    return WorkResponse()
      ..exitCode = exitCode
      ..output = output.toString();
  }
}

Future<int> _run(List<String> args, {void printFn(Object obj)}) async {
  var printedError = false;
  printFn ??= print;

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
      stderr.writeln(Trace.from(stackTrace).terse.toString().trimRight());
    }
  }

  ExecutableOptions options;
  try {
    options = ExecutableOptions.parse(args);
    term_glyph.ascii = !options.unicode;

    if (options.version) {
      printFn(await _loadVersion());
      exitCode = 0;
      return exitCode;
    }

    if (options.interactive) {
      await repl(options);
      return exitCode;
    }

    var graph = StylesheetGraph(
        ImportCache([], loadPaths: options.loadPaths, logger: options.logger));
    if (options.watch) {
      await watch(options, graph);
      return exitCode;
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
        if (options.stopOnError) return exitCode;
      } on FileSystemException catch (error, stackTrace) {
        printError("Error reading ${p.relative(error.path)}: ${error.message}.",
            options.trace ? stackTrace : null);

        // Error 66 indicates no input.
        exitCode = 66;
        if (options.stopOnError) return exitCode;
      }
    }
  } on UsageException catch (error) {
    printFn("${error.message}\n");
    printFn("Usage: sass <input.scss> [output.css]\n"
        "       sass <input.scss>:<output.css> <input/>:<output/> <dir/>\n");
    printFn(ExecutableOptions.usage);
    exitCode = 64;
  } catch (error, stackTrace) {
    var buffer = StringBuffer();
    if (options != null && options.color) buffer.write('\u001b[31m\u001b[1m');
    buffer.write('Unexpected exception:');
    if (options != null && options.color) buffer.write('\u001b[0m');
    buffer.writeln();
    buffer.writeln(error);

    printError(buffer.toString(), stackTrace);
    exitCode = 255;
  }
  return exitCode;
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
