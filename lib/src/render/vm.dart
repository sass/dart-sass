// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'shared.dart';
import '../ast/sass.dart';
import '../io.dart';
import '../sync_package_resolver.dart';

String render(String path,
    {bool color: false,
    SyncPackageResolver packageResolver,
    String indentType,
    int indentWidth}) {
  if (indentType != null) {
    stderr.writeln("Error: indentStyle is unsupported by Dart Sass.");
    exitCode = 1;
    return;
  }
  if (indentWidth != null) {
    stderr.writeln("Error: indentWidth is unsupported by Dart Sass.");
    exitCode = 1;
    return;
  }
  var contents = readFile(path);
  var url = p.toUri(path);
  return renderSourceToCss(contents, url,
      color: color,
      packageResolver: packageResolver,
      indentedSyntax: p.extension(path) == '.sass');
}
