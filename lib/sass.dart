// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'src/ast/sass.dart';
import 'src/exception.dart';
import 'src/io.dart';
import 'src/visitor/perform.dart';
import 'src/visitor/serialize.dart';

/// Loads the Sass file at [path], converts it to CSS, and returns the result.
///
/// Throws a [SassException] if conversion fails.
String render(String path) {
  var contents = readFile(path);
  var url = p.toUri(path);
  var sassTree = p.extension(path) == '.sass'
      ? new Stylesheet.parseSass(contents, url: url)
      : new Stylesheet.parseScss(contents, url: url);
  var cssTree = evaluate(sassTree);
  return toCss(cssTree);
}
