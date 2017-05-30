// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'ast/sass.dart';
import 'exception.dart';
import 'io.dart';
import 'sync_package_resolver.dart';
import 'visitor/perform.dart';
import 'visitor/serialize.dart';

/// Loads the Sass file at [path], converts it to CSS, and returns the result.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// If [packageResolver] is provided, it's used to resolve `package:` imports.
/// Otherwise, they aren't supported. It takes a [SyncPackageResolver][] from
/// the `package_resolver` package.
///
/// [SyncPackageResolver]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
///
/// Finally throws a [SassException] if conversion fails.
String render(String path,
    {bool color: false,
    SyncPackageResolver packageResolver,
    String indentType: 'space',
    int indentWidth: 2}) {
  if (indentType != 'space' && indentType != 'tab') {
    stderr.writeln("Error: $indentType is an invalid indent type; must be "
        "either 'space' or 'tab'.");
    exitCode = 1;
    return null;
  }
  if (indentWidth < 0 || indentWidth > 10) {
    stderr.writeln("Error: $indentWidth is an invalid indent width; must be "
        "between 0 and 10, inclusive.");
    exitCode = 1;
    return null;
  }
  var contents = readFile(path);
  var url = p.toUri(path);
  var sassTree = p.extension(path) == '.sass'
      ? new Stylesheet.parseSass(contents, url: url, color: color)
      : new Stylesheet.parseScss(contents, url: url, color: color);
  var cssTree =
      evaluate(sassTree, color: color, packageResolver: packageResolver);
  return toCss(cssTree, indentType: indentType, indentWidth: indentWidth);
}
