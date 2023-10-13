// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../io.dart';
import '../stylesheet_graph.dart';
import '../util/map.dart';
import 'compile_stylesheet.dart';
import 'concurrent/vm.dart'
    // Never load the isolate library when compiling to JS.
    if (dart.library.js) 'concurrent/js.dart';
import 'options.dart';

/// Compiles the stylesheets concurrently and returns whether all stylesheets are compiled
/// successfully.
Future<bool> compileStylesheets(ExecutableOptions options,
    StylesheetGraph graph, Map<String?, String?> sourcesToDestinations,
    {bool ifModified = false}) async {
  var errorsWithStackTraces = switch ([...sourcesToDestinations.pairs]) {
    // Concurrency does add some overhead, so avoid it in the common case of
    // compiling a single stylesheet.
    [(var source, var destination)] => [
        await compileStylesheet(options, graph, source, destination,
            ifModified: ifModified)
      ],
    var pairs => await Future.wait([
        for (var (source, destination) in pairs)
          compileStylesheetConcurrently(options, graph, source, destination,
              ifModified: ifModified)
      ], eagerError: options.stopOnError)
  };

  var printedError = false;

  // Print all errors in deterministic order.
  for (var errorWithStackTrace in errorsWithStackTraces) {
    if (errorWithStackTrace == null) continue;
    var (code, error, stackTrace) = errorWithStackTrace;

    // We let the highest exitCode take precedence for deterministic behavior.
    exitCode = math.max(exitCode, code);

    _printError(error, stackTrace, printedError);
    printedError = true;
  }

  return !printedError;
}

// Prints [error] to stderr, along with a preceding newline if anything else
// has been printed to stderr.
//
// If [stackTrace] is passed, it is printed after the error.
void _printError(String error, String? stackTrace, bool printedError) {
  var buffer = StringBuffer();
  if (printedError) buffer.writeln();
  buffer.write(error);
  if (stackTrace != null) {
    buffer.writeln();
    buffer.writeln();
    buffer.write(stackTrace);
  }
  printError(buffer);
}
