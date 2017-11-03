// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'importer.dart';
import 'importer/filesystem.dart';
import 'importer/node.dart';
import 'importer/package.dart';
import 'io.dart';
import 'sync_package_resolver.dart';
import 'util/path.dart';
import 'visitor/evaluate.dart';
import 'visitor/serialize.dart';

/// Like [compile] in `lib/sass.dart`, but provides more options to support the
/// node-sass compatible API.
CompileResult compile(String path,
        {bool indented,
        bool color: false,
        Iterable<Importer> importers,
        NodeImporter nodeImporter,
        SyncPackageResolver packageResolver,
        Iterable<String> loadPaths,
        OutputStyle style,
        bool useSpaces: true,
        int indentWidth,
        LineFeed lineFeed}) =>
    compileString(readFile(path),
        indented: indented ?? p.extension(path) == '.sass',
        color: color,
        importers: importers,
        nodeImporter: nodeImporter,
        packageResolver: packageResolver,
        loadPaths: loadPaths,
        importer: new FilesystemImporter('.'),
        style: style,
        useSpaces: useSpaces,
        indentWidth: indentWidth,
        lineFeed: lineFeed,
        url: p.toUri(path));

/// Like [compileString] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API.
CompileResult compileString(String source,
    {bool indented: false,
    bool color: false,
    Iterable<Importer> importers,
    NodeImporter nodeImporter,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    Importer importer,
    OutputStyle style,
    bool useSpaces: true,
    int indentWidth,
    LineFeed lineFeed,
    url}) {
  var sassTree = indented
      ? new Stylesheet.parseSass(source, url: url, color: color)
      : new Stylesheet.parseScss(source, url: url, color: color);

  var importerList = (importers?.toList() ?? []);
  if (loadPaths != null) {
    importerList.addAll(loadPaths.map((path) => new FilesystemImporter(path)));
  }
  if (packageResolver != null) {
    importerList.add(new PackageImporter(packageResolver));
  }

  var evaluateResult = evaluate(sassTree,
      importers: importerList,
      nodeImporter: nodeImporter,
      importer: importer,
      color: color);
  var css = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed);

  return new CompileResult(css, evaluateResult.includedFiles);
}

/// The result of compiling a Sass document to CSS, along with metadata about
/// the compilation process.
class CompileResult {
  /// The compiled CSS.
  final String css;

  /// The set that will eventually populate the JS API's
  /// `result.stats.includedFiles` field.
  ///
  /// For filesystem imports, this contains the import path. For all other
  /// imports, it contains the URL passed to the `@import`.
  final Set<String> includedFiles;

  CompileResult(this.css, this.includedFiles);
}
