// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;
import 'package:sass/src/sync_package_resolver/sync_package_resolver.dart';

import 'src/ast/sass.dart';
import 'src/utils.dart';
import 'src/visitor/perform.dart';
import 'src/visitor/serialize.dart';

/// Loads the Sass file at [path], converts it to CSS, and returns the result.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// If [packageResolver] is provided, tries to resolve the imports with "package" uri
/// to the dart-package uri. If file doesn't exist inside the dart-package folder,
/// throws a [SassException]. For example if next code is found:
///
/// ```sass
/// @import "package:sass/all";
/// ```
///
/// will try to open the file `~/.pub-cache/hosted/pub.dartlang.org/sass-X.X.X/all.scss`
/// in POSIX systems.
///
/// Finally throws a [SassException] if conversion fails.
String render(String path,
    {bool color: false, SyncPackageResolver packageResolver}) {
  var contents = readSassFile(path);
  var url = p.toUri(path);
  var sassTree = p.extension(path) == '.sass'
      ? new Stylesheet.parseSass(contents, url: url, color: color)
      : new Stylesheet.parseScss(contents, url: url, color: color);
  var cssTree =
      evaluate(sassTree, color: color, packageResolver: packageResolver);
  return toCss(cssTree);
}
