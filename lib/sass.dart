// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'package:path/path.dart' as p;

import 'src/ast/sass.dart';
import 'src/exception.dart';
import 'src/utils.dart';
import 'src/visitor/perform.dart';
import 'src/visitor/serialize.dart';

/// Loads the Sass file at [path], converts it to CSS, and returns the result.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// Throws a [SassException] if conversion fails.
Future<String> render(String path, {bool color: false}) async {
  var contents = readSassFile(path);
  var url = p.toUri(path);
  var sassTree = p.extension(path) == '.sass'
      ? new Stylesheet.parseSass(contents, url: url, color: color)
      : new Stylesheet.parseScss(contents, url: url, color: color);
  var cssTree = await evaluate(sassTree, color: color);
  return toCss(cssTree);
}
