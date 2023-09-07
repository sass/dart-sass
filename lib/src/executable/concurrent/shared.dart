// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

import '../compile_stylesheet.dart';
import '../options.dart';
import '../../exception.dart';
import '../../io.dart';
import '../../stylesheet_graph.dart';
import '../../utils.dart';

/// Compiles the stylesheet at [source] to [destination].
///
/// Returns `(exitCode, error, stackTrace)` when an error occurs.
///
/// In the current pure JS implementation it is single threaded.
Future<(int, String, String?)?> compileStylesheetConcurrently(
    ExecutableOptions options,
    StylesheetGraph graph,
    String? source,
    String? destination,
    {bool ifModified = false}) async {
  try {
    await compileStylesheet(options, graph, source, destination,
        ifModified: ifModified);
  } on SassException catch (error, stackTrace) {
    if (destination != null && !options.emitErrorCss) {
      _tryDelete(destination);
    }
    var message = error.toString(color: options.color);

    // Exit code 65 indicates invalid data per
    // https://www.freebsd.org/cgi/man.cgi?query=sysexits.
    return _getErrorWithStackTrace(
        65, message, options.trace ? getTrace(error) ?? stackTrace : null);
  } on FileSystemException catch (error, stackTrace) {
    var path = error.path;
    var message = path == null
        ? error.message
        : "Error reading ${p.relative(path)}: ${error.message}.";

    // Exit code 66 indicates no input.
    return _getErrorWithStackTrace(
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

/// Return a Record of `(exitCode, error, stackTrace)` for the given error.
(int, String, String?) _getErrorWithStackTrace(
    int exitCode, String error, StackTrace? stackTrace) {
  return (
    exitCode,
    error,
    stackTrace != null
        ? Trace.from(stackTrace).terse.toString().trimRight()
        : null
  );
}
