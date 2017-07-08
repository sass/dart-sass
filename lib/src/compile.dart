// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'io.dart';
import 'sync_package_resolver.dart';
import 'util/path.dart';
import 'visitor/perform.dart';
import 'visitor/serialize.dart';

/// Like [compile] in `lib/sass.dart`, but provides more options to support the
/// node-sass compatible API.
String compile(String path,
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
String compileString(String source,
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
  var cssTree = evaluate(sassTree,
      color: color, packageResolver: packageResolver, loadPaths: loadPaths);
  return toCss(cssTree,
      style: style,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed);
}
