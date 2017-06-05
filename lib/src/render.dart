// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'ast/sass.dart';
import 'io.dart';
import 'sync_package_resolver.dart';
import 'visitor/perform.dart';
import 'visitor/serialize.dart';

/// Like [render] in `lib/sass.dart`, but provides more options to support the
/// node-sass compatible API.
String render(String path,
    {bool color: false,
    SyncPackageResolver packageResolver,
    bool useSpaces: true,
    int indentWidth: 2}) {
  RangeError.checkValueInInterval(indentWidth, 0, 10, "indentWidth");

  var contents = readFile(path);
  var url = p.toUri(path);
  var sassTree = p.extension(path) == '.sass'
      ? new Stylesheet.parseSass(contents, url: url, color: color)
      : new Stylesheet.parseScss(contents, url: url, color: color);
  var cssTree =
      evaluate(sassTree, color: color, packageResolver: packageResolver);
  return toCss(cssTree, useSpaces: useSpaces, indentWidth: indentWidth);
}

/// Like [renderSource] in `lib/sass.dart`, but provides more options to support the
/// node-sass compatible API.
String renderSource(String source,
    {bool color: false,
    SyncPackageResolver packageResolver,
    bool useSpaces: true,
    int indentWidth: 2,
    String url}) {
  RangeError.checkValueInInterval(indentWidth, 0, 10, "indentWidth");

  var sassTree = new Stylesheet.parseScss(source,
      url: url == null ? url : Uri.parse(url), color: color);
  var cssTree =
      evaluate(sassTree, color: color, packageResolver: packageResolver);
  return toCss(cssTree);
}
