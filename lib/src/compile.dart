// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_compile.dart.
// See tool/synchronize.dart for details.
//
// Checksum: e6de63e581c0f4da96756b9e2904bd81a090dc5b
//
// ignore_for_file: unused_import

import 'async_compile.dart';
export 'async_compile.dart';

import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import 'ast/sass.dart';
import 'import_cache.dart';
import 'callable.dart';
import 'importer.dart';
import 'importer/node.dart';
import 'io.dart';
import 'logger.dart';
import 'sync_package_resolver.dart';
import 'syntax.dart';
import 'visitor/evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compile] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API and the executable.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
CompileResult compile(String path,
    {Syntax syntax,
    Logger logger,
    ImportCache importCache,
    NodeImporter nodeImporter,
    Iterable<Callable> functions,
    OutputStyle style,
    bool useSpaces = true,
    int indentWidth,
    LineFeed lineFeed,
    bool sourceMap = false}) {
  // If the syntax is different than the importer would default to, we have to
  // parse the file manually and we can't store it in the cache.
  Stylesheet stylesheet;
  if (nodeImporter == null &&
      (syntax == null || syntax == Syntax.forPath(path))) {
    importCache ??= ImportCache.none(logger: logger);
    stylesheet = importCache.importCanonical(
        FilesystemImporter('.'), p.toUri(p.canonicalize(path)), p.toUri(path));
  } else {
    stylesheet = Stylesheet.parse(
        readFile(path), syntax ?? Syntax.forPath(path),
        url: p.toUri(path), logger: logger);
  }

  return _compileStylesheet(
      stylesheet,
      logger,
      importCache,
      nodeImporter,
      FilesystemImporter('.'),
      functions,
      style,
      useSpaces,
      indentWidth,
      lineFeed,
      sourceMap);
}

/// Like [compileString] in `lib/sass.dart`, but provides more options to
/// support the node-sass compatible API.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
CompileResult compileString(String source,
    {Syntax syntax,
    Logger logger,
    ImportCache importCache,
    NodeImporter nodeImporter,
    Iterable<Importer> importers,
    Iterable<String> loadPaths,
    SyncPackageResolver packageResolver,
    Importer importer,
    Iterable<Callable> functions,
    OutputStyle style,
    bool useSpaces = true,
    int indentWidth,
    LineFeed lineFeed,
    url,
    bool sourceMap = false}) {
  var stylesheet =
      Stylesheet.parse(source, syntax ?? Syntax.scss, url: url, logger: logger);

  return _compileStylesheet(
      stylesheet,
      logger,
      importCache,
      nodeImporter,
      importer ?? FilesystemImporter('.'),
      functions,
      style,
      useSpaces,
      indentWidth,
      lineFeed,
      sourceMap);
}

/// Compiles [stylesheet] and returns its result.
///
/// Arguments are handled as for [compileString].
CompileResult _compileStylesheet(
    Stylesheet stylesheet,
    Logger logger,
    ImportCache importCache,
    NodeImporter nodeImporter,
    Importer importer,
    Iterable<Callable> functions,
    OutputStyle style,
    bool useSpaces,
    int indentWidth,
    LineFeed lineFeed,
    bool sourceMap) {
  var evaluateResult = evaluate(stylesheet,
      importCache: importCache,
      nodeImporter: nodeImporter,
      importer: importer,
      functions: functions,
      logger: logger,
      sourceMap: sourceMap);

  var serializeResult = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed,
      sourceMap: sourceMap);

  return CompileResult(evaluateResult, serializeResult);
}
