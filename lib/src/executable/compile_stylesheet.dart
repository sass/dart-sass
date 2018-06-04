// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:dart2_constant/convert.dart' as convert;
import 'package:source_maps/source_maps.dart';

import '../../sass.dart';
import '../ast/sass.dart';
import '../async_import_cache.dart';
import '../import_cache.dart';
import '../io.dart';
import '../stylesheet_graph.dart';
import '../util/path.dart';
import '../visitor/async_evaluate.dart';
import '../visitor/evaluate.dart';
import '../visitor/serialize.dart';
import 'options.dart';

/// Compiles the stylesheet at [source] to [destination].
///
/// Loads files using `graph.importCache` when possible.
///
/// If [source] is `null`, that indicates that the stylesheet should be read
/// from stdin. If [destination] is `null`, that indicates that the stylesheet
/// should be emitted to stdout.
Future compileStylesheet(ExecutableOptions options, StylesheetGraph graph,
    String source, String destination) async {
  var importer = new FilesystemImporter('.');
  if (options.update) {
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

  var stylesheet = await _parseStylesheet(options, graph.importCache, source);
  var evaluateResult = options.asynchronous
      ? await evaluateAsync(stylesheet,
          importCache: new AsyncImportCache([],
              loadPaths: options.loadPaths, logger: options.logger),
          importer: importer,
          logger: options.logger,
          sourceMap: options.emitSourceMap)
      : await evaluate(stylesheet,
          importCache: graph.importCache,
          importer: importer,
          logger: options.logger,
          sourceMap: options.emitSourceMap);

  var serializeResult = serialize(evaluateResult.stylesheet,
      style: options.style, sourceMap: options.emitSourceMap);

  var css = serializeResult.css;
  css += _writeSourceMap(options, serializeResult.sourceMap, destination);
  if (destination == null) {
    if (css.isNotEmpty) print(css);
  } else {
    ensureDir(p.dirname(destination));
    writeFile(destination, css + "\n");
  }

  if (!options.update || options.quiet) return;
  var buffer = new StringBuffer();
  if (options.color) buffer.write('\u001b[32m');
  buffer.write('Compiled ${source ?? 'stdin'} to $destination.');
  if (options.color) buffer.write('\u001b[0m');
  print(buffer);
}

/// Parses [source] according to [options], loading it from [graph] if
/// possible.
///
/// Returns the parsed [Stylesheet].
Future<Stylesheet> _parseStylesheet(
    ExecutableOptions options, ImportCache importCache, String source) async {
  // Import from the cache if possible so it caches the file in case anything
  // else imports it.
  if (source != null && options.indented == null) {
    return importCache.importCanonical(new FilesystemImporter('.'),
        p.toUri(p.absolute(source)), p.toUri(source));
  }

  var text = source == null ? await readStdin() : readFile(source);
  var url = source == null ? null : p.toUri(source);
  return options.indented ?? (source != null && p.extension(source) == '.sass')
      ? new Stylesheet.parseSass(text, url: url, logger: options.logger)
      : new Stylesheet.parseScss(text, url: url, logger: options.logger);
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

  for (var i = 0; i < sourceMap.urls.length; i++) {
    var url = sourceMap.urls[i];

    // The special URL "" indicates a file that came from stdin.
    if (url == "") continue;

    sourceMap.urls[i] =
        options.sourceMapUrl(Uri.parse(url), destination).toString();
  }
  var sourceMapText = convert.json
      .encode(sourceMap.toJson(includeSourceContents: options.embedSources));

  Uri url;
  if (options.embedSourceMap) {
    url = new Uri.dataFromString(sourceMapText, mimeType: 'application/json');
  } else {
    var sourceMapPath = destination + '.map';
    ensureDir(p.dirname(sourceMapPath));
    writeFile(sourceMapPath, sourceMapText);

    url = p.toUri(sourceMapPath);
  }

  return (options.style == OutputStyle.compressed ? '' : '\n\n') +
      '/*# sourceMappingURL=$url */';
}
