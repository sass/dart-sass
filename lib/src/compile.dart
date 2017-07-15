// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
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
        SyncPackageResolver packageResolver,
        Iterable<String> loadPaths,
        OutputStyle style,
        bool useSpaces: true,
        int indentWidth,
        LineFeed lineFeed}) =>
    compileString(readFile(path),
        indented: indented ?? p.extension(path) == '.sass',
        color: color,
        packageResolver: packageResolver,
        style: style,
        loadPaths: loadPaths,
        useSpaces: useSpaces,
        indentWidth: indentWidth,
        lineFeed: lineFeed,
        url: p.toUri(path));

/// Like [compileString] in `lib/sass.dart`, but provides more options to support
/// the node-sass compatible API.
CompileResult compileString(String source,
    {bool indented: false,
    bool color: false,
    SyncPackageResolver packageResolver,
    Iterable<String> loadPaths,
    OutputStyle style,
    bool useSpaces: true,
    int indentWidth,
    LineFeed lineFeed,
    url}) {
  var sassTree = indented
      ? new Stylesheet.parseSass(source, url: url, color: color)
      : new Stylesheet.parseScss(source, url: url, color: color);
  var evaluateResult = evaluate(sassTree,
      color: color, packageResolver: packageResolver, loadPaths: loadPaths);
  var css = serialize(evaluateResult.stylesheet,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed);

  return new CompileResult(css, evaluateResult.includedUrls);
}

/// The result of compiling a Sass document to CSS, along with metadata about
/// the compilation process.
class CompileResult {
  /// The compiled CSS.
  final String css;

  /// The URLs that were loaded during the compilation, including the main
  /// file's.
  final Set<Uri> includedUrls;

  CompileResult(this.css, this.includedUrls);
}
