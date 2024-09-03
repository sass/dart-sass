// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:stack_trace/stack_trace.dart';

import '../async_import_cache.dart';
import '../compile.dart';
import '../compile_result.dart';
import '../exception.dart';
import '../importer/filesystem.dart';
import '../io.dart';
import '../stylesheet_graph.dart';
import '../syntax.dart';
import '../utils.dart';
import '../visitor/serialize.dart';
import 'options.dart';

/// Compiles the stylesheet at [source] to [destination].
///
/// Loads files using `graph.importCache` when possible.
///
/// If [source] is `null`, that indicates that the stylesheet should be read
/// from stdin. If [destination] is `null`, that indicates that the stylesheet
/// should be emitted to stdout.
///
/// If [ifModified] is `true`, only recompiles if [source]'s modification time
/// or that of a file it imports is more recent than [destination]'s
/// modification time. Note that these modification times are cached by [graph].
///
/// Returns `(exitCode, error, stackTrace)` when an error occurs.
Future<(int, String, String?)?> compileStylesheet(ExecutableOptions options,
    StylesheetGraph graph, String? source, String? destination,
    {bool ifModified = false}) async {
  try {
    await _compileStylesheetWithoutErrorHandling(
        options, graph, source, destination,
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

/// Like [compileStylesheet], but throws errors instead of handling them
/// internally.
Future<void> _compileStylesheetWithoutErrorHandling(ExecutableOptions options,
    StylesheetGraph graph, String? source, String? destination,
    {bool ifModified = false}) async {
  var importer = FilesystemImporter.cwd;
  if (ifModified) {
    try {
      if (source != null &&
          destination != null &&
          !graph.modifiedSince(p.toUri(p.absolute(source)),
              modificationTime(destination), importer)) {
        return;
      }
    } on FileSystemException catch (_) {
      // Compile as normal if the destination file doesn't exist.
    }
  }

  Syntax syntax;
  if (options.indented == true) {
    syntax = Syntax.sass;
  } else if (source != null) {
    syntax = Syntax.forPath(source);
  } else {
    syntax = Syntax.scss;
  }

  CompileResult result;
  try {
    if (options.asynchronous) {
      var importCache = AsyncImportCache(
          importers: options.pkgImporters,
          loadPaths: options.loadPaths,
          logger: AsyncImportCache.wrapLogger(
              options.logger,
              options.silenceDeprecations,
              options.fatalDeprecations,
              options.futureDeprecations));

      result = source == null
          ? await compileStringAsync(await readStdin(),
              syntax: syntax,
              logger: options.logger,
              importCache: importCache,
              importer: FilesystemImporter.cwd,
              style: options.style,
              quietDeps: options.quietDeps,
              verbose: options.verbose,
              sourceMap: options.emitSourceMap,
              charset: options.charset,
              silenceDeprecations: options.silenceDeprecations,
              fatalDeprecations: options.fatalDeprecations,
              futureDeprecations: options.futureDeprecations)
          : await compileAsync(source,
              syntax: syntax,
              logger: options.logger,
              importCache: importCache,
              style: options.style,
              quietDeps: options.quietDeps,
              verbose: options.verbose,
              sourceMap: options.emitSourceMap,
              charset: options.charset,
              silenceDeprecations: options.silenceDeprecations,
              fatalDeprecations: options.fatalDeprecations,
              futureDeprecations: options.futureDeprecations);
    } else {
      result = source == null
          ? compileString(await readStdin(),
              syntax: syntax,
              logger: options.logger,
              importCache: graph.importCache,
              importer: FilesystemImporter.cwd,
              style: options.style,
              quietDeps: options.quietDeps,
              verbose: options.verbose,
              sourceMap: options.emitSourceMap,
              charset: options.charset,
              silenceDeprecations: options.silenceDeprecations,
              fatalDeprecations: options.fatalDeprecations,
              futureDeprecations: options.futureDeprecations)
          : compile(source,
              syntax: syntax,
              logger: options.logger,
              importCache: graph.importCache,
              style: options.style,
              quietDeps: options.quietDeps,
              verbose: options.verbose,
              sourceMap: options.emitSourceMap,
              charset: options.charset,
              silenceDeprecations: options.silenceDeprecations,
              fatalDeprecations: options.fatalDeprecations,
              futureDeprecations: options.futureDeprecations);
    }
  } on SassException catch (error) {
    if (options.emitErrorCss) {
      if (destination == null) {
        print(error.toCssString());
      } else {
        ensureDir(p.dirname(destination));
        writeFile(destination, error.toCssString() + "\n");
      }
    }
    rethrow;
  }

  var css = result.css;
  css += _writeSourceMap(options, result.sourceMap, destination);
  if (destination == null) {
    if (css.isNotEmpty) print(css);
  } else {
    ensureDir(p.dirname(destination));
    writeFile(destination, css + "\n");
  }

  if (options.quiet || (!options.update && !options.watch)) return;
  var buffer = StringBuffer();

  var sourceName = source == null ? 'stdin' : p.prettyUri(p.toUri(source));
  // `destination` is guaranteed to be non-null in update and watch mode.
  var destinationName = p.prettyUri(p.toUri(destination!));

  var nowStr = DateTime.now().toString();
  // Remove fractional seconds from printed timestamp
  var timestamp = nowStr.substring(0, nowStr.length - 7);

  if (options.color) buffer.write('\u001b[90m');
  buffer.write('[$timestamp] ');
  if (options.color) buffer.write('\u001b[32m');
  buffer.write('Compiled $sourceName to $destinationName.');
  if (options.color) buffer.write('\u001b[0m');

  safePrint(buffer);
}

/// Writes the source map given by [mapping] to disk (if necessary) according to
/// [options].
///
/// The [destination] is the path where the CSS file associated with this source
/// map will be written. If it's `null`, that indicates that the CSS will be
/// printed to stdout.
///
/// Returns the source map comment to add to the end of the CSS file.
String _writeSourceMap(
    ExecutableOptions options, SingleMapping? sourceMap, String? destination) {
  if (sourceMap == null) return "";

  if (destination != null) {
    sourceMap.targetUrl = p.toUri(p.basename(destination)).toString();
  }

  // TODO(nweiz): Don't explicitly use a type parameter when dart-lang/sdk#25490
  // is fixed.
  mapInPlace<String>(sourceMap.urls,
      (url) => options.sourceMapUrl(Uri.parse(url), destination).toString());
  var sourceMapText =
      jsonEncode(sourceMap.toJson(includeSourceContents: options.embedSources));

  Uri url;
  if (options.embedSourceMap) {
    url = Uri.dataFromString(sourceMapText,
        mimeType: 'application/json', encoding: utf8);
  } else {
    // [destination] can't be null here because --embed-source-map is
    // incompatible with writing to stdout.
    var sourceMapPath = destination! + '.map';
    ensureDir(p.dirname(sourceMapPath));
    writeFile(sourceMapPath, sourceMapText);

    url = p.toUri(p.relative(sourceMapPath, from: p.dirname(destination)));
  }

  var escapedUrl = url.toString().replaceAll("*/", '%2A/');

  return (options.style == OutputStyle.compressed ? '' : '\n\n') +
      '/*# sourceMappingURL=$escapedUrl */';
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
