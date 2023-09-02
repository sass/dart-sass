// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../compile_stylesheet.dart' as c;
import '../options.dart';
import '../../exception.dart';
import '../../io.dart';
import '../../stylesheet_graph.dart';
import '../../utils.dart';

/// Compiles the stylesheet at [source] to [destination].
///
/// Returns `(exitCode, error, stackTrace)` when error occurs.
Future<(int, String, String?)?> compileStylesheet(ExecutableOptions options,
    StylesheetGraph graph, String? source, String? destination,
    {bool ifModified = false}) async {
  try {
    await c.compileStylesheet(options, graph, source, destination,
        ifModified: ifModified);
  } on SassException catch (error, stackTrace) {
    if (destination != null && !options.emitErrorCss) {
      _tryDelete(destination);
    }
    var message = error.toString(color: options.color);

    // Exit code 65 indicates invalid data per
    // https://www.freebsd.org/cgi/man.cgi?query=sysexits.
    return getErrorWithStackTrace(
        65, message, options.trace ? getTrace(error) ?? stackTrace : null);
  } on FileSystemException catch (error, stackTrace) {
    var path = error.path;
    var message = path == null
        ? error.message
        : "Error reading ${p.relative(path)}: ${error.message}.";

    // Exit code 66 indicates no input.
    return getErrorWithStackTrace(
        66, message, options.trace ? getTrace(error) ?? stackTrace : null);
  }
  return null;
}

/// Delete [path] if it exists and do nothing otherwise.
///
/// This is a separate function to work around dart-lang/sdk#53082.
void _tryDelete(String path) {
  try {
    deleteFile(path);
  } on FileSystemException {
    // If the file doesn't exist, that's fine.
  }
}

// Prints [error] to stderr, along with a preceding newline if anything else
// has been printed to stderr.
//
// If [trace] is passed, its terse representation is printed after the error.
(int, String, String?) getErrorWithStackTrace(
    int exitCode, String error, StackTrace? stackTrace) {
  return (
    exitCode,
    error,
    stackTrace != null
        ? Trace.from(stackTrace).terse.toString().trimRight()
        : null
  );
}
