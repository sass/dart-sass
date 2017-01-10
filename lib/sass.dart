// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'package:path/path.dart' as p;

import 'package:sass/src/sync_package_resolver/index.dart';
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

/// Loads the Sass file at [path], converts it to CSS, and returns the result in async way.
/// It also uses the SyncPackageResolver to resolve package uri.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// Throws a [SassException] if conversion fails.
Future<String> renderAsync(String path, {bool color: false}) async =>
    render(path,
        color: color, packageResolver: await SyncPackageResolver.current);
