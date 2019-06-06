// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';

import '../async_import_cache.dart';
import '../compile.dart';
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
Future<void> compileStylesheet(ExecutableOptions options, StylesheetGraph graph,
    String source, String destination,
    {bool ifModified = false}) async {
  var importer = FilesystemImporter('.');
  if (ifModified) {
    try {
      if (source != null &&
          destination != null &&
          !graph.modifiedSince(
              p.toUri(source), modificationTime(destination), importer)) {
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
      var importCache = AsyncImportCache([],
          loadPaths: options.loadPaths, logger: options.logger);

      result = source == null
          ? await compileStringAsync(await readStdin(),
              syntax: syntax,
              logger: options.logger,
              importCache: importCache,
              importer: FilesystemImporter('.'),
              style: options.style,
              sourceMap: options.emitSourceMap,
              charset: options.charset)
          : await compileAsync(source,
              syntax: syntax,
              logger: options.logger,
              importCache: importCache,
              style: options.style,
              sourceMap: options.emitSourceMap,
              charset: options.charset);
    } else {
      result = source == null
          ? compileString(await readStdin(),
              syntax: syntax,
              logger: options.logger,
              importCache: graph.importCache,
              importer: FilesystemImporter('.'),
              style: options.style,
              sourceMap: options.emitSourceMap,
              charset: options.charset)
          : compile(source,
              syntax: syntax,
              logger: options.logger,
              importCache: graph.importCache,
              style: options.style,
              sourceMap: options.emitSourceMap,
              charset: options.charset);
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
  if (options.color) buffer.write('\u001b[32m');

  var sourceName = source == null ? 'stdin' : p.prettyUri(p.toUri(source));
  var destinationName = p.prettyUri(p.toUri(destination));
  buffer.write('Compiled $sourceName to $destinationName.');
  if (options.color) buffer.write('\u001b[0m');
  print(buffer);
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
    ExecutableOptions options, SingleMapping sourceMap, String destination) {
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
    var sourceMapPath = destination + '.map';
    ensureDir(p.dirname(sourceMapPath));
    writeFile(sourceMapPath, sourceMapText);

    url = p.toUri(p.relative(sourceMapPath, from: p.dirname(destination)));
  }

  return (options.style == OutputStyle.compressed ? '' : '\n\n') +
      '/*# sourceMappingURL=$url */';
}
