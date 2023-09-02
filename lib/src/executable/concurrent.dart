// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import '../io.dart';
import '../stylesheet_graph.dart';
import 'concurrent/js.dart' as c;
import 'concurrent/vm.dart'
    // Never load the isolate when compiling to JS.
    if (dart.library.js) 'concurrent/js.dart';
import 'options.dart';

/// Compiles the stylesheets concurrently and returns whether all stylesheets are compiled
/// successfully.
Future<bool> compileStylesheets(
    ExecutableOptions options,
    StylesheetGraph graph,
    Iterable<(String?, String?)> sourcesToDestinationsPairs,
    {bool ifModified = false}) async {
  var errorsWithStackTraces = sourcesToDestinationsPairs.length == 1
      ? [
          await c.compileStylesheet(
              options,
              graph,
              sourcesToDestinationsPairs.first.$1,
              sourcesToDestinationsPairs.first.$2,
              ifModified: ifModified)
        ]
      : await Future.wait([
          for (var (source, destination) in sourcesToDestinationsPairs)
            compileStylesheet(options, graph, source, destination,
                ifModified: ifModified)
        ], eagerError: options.stopOnError);

  var printedError = false;

  // Print all errors in deterministic order.
  for (var errorWithStackTrace in errorsWithStackTraces) {
    if (errorWithStackTrace == null) continue;
    var (code, error, stackTrace) = errorWithStackTrace;
    switch (code) {
      case 65:
        // We let exitCode 66 take precedence for deterministic behavior.
        if (exitCode != 66) exitCode = code;
      case 66:
        exitCode = code;
    }
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
