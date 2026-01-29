// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:cli_pkg/js.dart';
import 'package:path/path.dart' as p;

import 'ast/sass.dart';
import 'async_import_cache.dart';
import 'callable.dart';
import 'compile_result.dart';
import 'deprecation.dart';
import 'importer.dart';
import 'importer/legacy_node.dart';
import 'importer/no_op.dart';
import 'io.dart';
import 'logger.dart';
import 'logger/deprecation_processing.dart';
import 'source_map_include_sources.dart';
import 'syntax.dart';
import 'visitor/async_evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compileAsync] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API and the executable.
///
/// If both `importCache` and `nodeImporter` are provided, the importers in
/// `importCache` will be evaluated before `nodeImporter`.
Future<CompileResult> compileAsync(
  String path, {
  Syntax? syntax,
  Logger? logger,
  AsyncImportCache? importCache,
  NodeImporter? nodeImporter,
  Iterable<AsyncCallable>? functions,
  OutputStyle? style,
  bool useSpaces = true,
  int? indentWidth,
  LineFeed? lineFeed,
  bool quietDeps = false,
  bool verbose = false,
  bool sourceMap = false,
  SourceMapIncludeSources sourceMapIncludeSources =
      SourceMapIncludeSources.always,
  bool charset = true,
  Iterable<Deprecation>? silenceDeprecations,
  Iterable<Deprecation>? fatalDeprecations,
  Iterable<Deprecation>? futureDeprecations,
}) async {
  DeprecationProcessingLogger deprecationLogger =
      logger = DeprecationProcessingLogger(
    logger ?? Logger.stderr(),
    silenceDeprecations: {...?silenceDeprecations},
    fatalDeprecations: {...?fatalDeprecations},
    futureDeprecations: {...?futureDeprecations},
    limitRepetition: !verbose,
  )..validate();

  // If the syntax is different than the importer would default to, we have to
  // parse the file manually and we can't store it in the cache.
  Stylesheet? stylesheet;
  if (nodeImporter == null &&
      (syntax == null || syntax == Syntax.forPath(path))) {
    importCache ??= AsyncImportCache.none();
    stylesheet = (await importCache.importCanonical(
      FilesystemImporter.cwd,
      p.toUri(canonicalize(path)),
      originalUrl: p.toUri(path),
    ))!;
  } else {
    stylesheet = Stylesheet.parse(
      readFile(path),
      syntax ?? Syntax.forPath(path),
      url: p.toUri(path),
    );
  }

  var result = await _compileStylesheet(
    stylesheet,
    logger,
    importCache,
    nodeImporter,
    FilesystemImporter.cwd,
    functions,
    style,
    useSpaces,
    indentWidth,
    lineFeed,
    quietDeps,
    sourceMap,
    sourceMapIncludeSources,
    charset,
  );

  deprecationLogger.summarize(js: nodeImporter != null);
  return result;
}

/// Like [compileStringAsync] in `lib/sass.dart`, but provides more options to
/// support the node-sass compatible API.
///
/// At most one of `importCache` and `nodeImporter` may be provided at once.
Future<CompileResult> compileStringAsync(
  String source, {
  Syntax? syntax,
  Logger? logger,
  AsyncImportCache? importCache,
  NodeImporter? nodeImporter,
  Iterable<AsyncImporter>? importers,
  Iterable<String>? loadPaths,
  AsyncImporter? importer,
  Iterable<AsyncCallable>? functions,
  OutputStyle? style,
  bool useSpaces = true,
  int? indentWidth,
  LineFeed? lineFeed,
  Object? url,
  bool quietDeps = false,
  bool verbose = false,
  bool sourceMap = false,
  SourceMapIncludeSources sourceMapIncludeSources =
      SourceMapIncludeSources.always,
  bool charset = true,
  Iterable<Deprecation>? silenceDeprecations,
  Iterable<Deprecation>? fatalDeprecations,
  Iterable<Deprecation>? futureDeprecations,
}) async {
  DeprecationProcessingLogger deprecationLogger =
      logger = DeprecationProcessingLogger(
    logger ?? Logger.stderr(),
    silenceDeprecations: {...?silenceDeprecations},
    fatalDeprecations: {...?fatalDeprecations},
    futureDeprecations: {...?futureDeprecations},
    limitRepetition: !verbose,
  )..validate();

  var stylesheet = Stylesheet.parse(source, syntax ?? Syntax.scss, url: url);

  if (stylesheet.span.sourceUrl case Uri(scheme: '')
      when nodeImporter == null) {
    deprecationLogger.warnForDeprecation(
      Deprecation.compileStringRelativeUrl,
      'Passing a relative `url` argument (${stylesheet.span.sourceUrl}) to '
      'compileString() or related functions is deprecated and will be an error '
      'in Dart Sass 2.0.0.',
    );
  }

  var result = await _compileStylesheet(
    stylesheet,
    logger,
    importCache,
    nodeImporter,
    importer ?? (isBrowser ? NoOpImporter() : FilesystemImporter.cwd),
    functions,
    style,
    useSpaces,
    indentWidth,
    lineFeed,
    quietDeps,
    sourceMap,
    sourceMapIncludeSources,
    charset,
  );

  deprecationLogger.summarize(js: nodeImporter != null);
  return result;
}

/// Compiles [stylesheet] and returns its result.
///
/// Arguments are handled as for [compileStringAsync].
Future<CompileResult> _compileStylesheet(
  Stylesheet stylesheet,
  Logger? logger,
  AsyncImportCache? importCache,
  NodeImporter? nodeImporter,
  AsyncImporter importer,
  Iterable<AsyncCallable>? functions,
  OutputStyle? style,
  bool useSpaces,
  int? indentWidth,
  LineFeed? lineFeed,
  bool quietDeps,
  bool sourceMap,
  SourceMapIncludeSources sourceMapIncludeSources,
  bool charset,
) async {
  if (nodeImporter != null) {
    logger?.warnForDeprecation(
      Deprecation.legacyJsApi,
      'The legacy JS API is deprecated and will be removed in '
      'Dart Sass 2.0.0.\n\n'
      'More info: https://sass-lang.com/d/legacy-js-api',
    );
  } else {
    if (sourceMapIncludeSources == SourceMapIncludeSources.true_ ||
        sourceMapIncludeSources == SourceMapIncludeSources.false_) {
      var boolean = sourceMapIncludeSources == SourceMapIncludeSources.true_;
      var suggestion = boolean ? 'always' : 'never';
      logger?.warnForDeprecation(
        Deprecation.sourceMapIncludeSourcesBoolean,
        'Passing a boolean value for Options.sourceMapIncludeSources is '
        'deprecated and will be removed in Dart Sass 2.0.0.\n'
        "Please use '$suggestion' instead of $boolean.\n\n"
        'More info: https://sass-lang.com/d/source-map-include-sources-boolean',
      );
      sourceMapIncludeSources =
          sourceMapIncludeSources == SourceMapIncludeSources.true_
              ? SourceMapIncludeSources.always
              : SourceMapIncludeSources.never;
    }
  }
  var evaluateResult = await evaluateAsync(
    stylesheet,
    importCache: importCache,
    nodeImporter: nodeImporter,
    importer: importer,
    functions: functions,
    logger: logger,
    quietDeps: quietDeps,
    sourceMap: sourceMap,
  );

  var serializeResult = serialize(
    evaluateResult.stylesheet,
    style: style,
    useSpaces: useSpaces,
    indentWidth: indentWidth,
    lineFeed: lineFeed,
    logger: logger,
    sourceMap: sourceMap,
    charset: charset,
  );

  var resultSourceMap = serializeResult.sourceMap;
  if (resultSourceMap != null) {
    if (importCache != null) {
      for (var i = 0, length = resultSourceMap.urls.length; i < length; i++) {
        var canonicalUrl = Uri.parse(resultSourceMap.urls[i]);
        var sourceMapUrl = importCache.sourceMapUrl(canonicalUrl);
        if (sourceMapUrl != null) {
          resultSourceMap.urls[i] = sourceMapUrl.toString();
          if (sourceMapIncludeSources == SourceMapIncludeSources.auto) {
            resultSourceMap.files[i] = null;
          }
        }
      }
    }
    if (sourceMapIncludeSources == SourceMapIncludeSources.never) {
      resultSourceMap.files.fillRange(0, resultSourceMap.files.length, null);
    }
  }

  return CompileResult(evaluateResult, serializeResult);
}
