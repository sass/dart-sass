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
    String indentType: 'space',
    int indentWidth: 2}) {
  if (indentType != 'space' && indentType != 'tab') {
    stderr.writeln("Error: $indentType is an invalid indent type; must be "
        "either 'space' or 'tab'.");
    exitCode = 1;
    return;
  }
  if (indentWidth < 0 || indentWidth > 10) {
    stderr.writeln("Error: $indentWidth is an invalid indent width; must be "
        "between 0 and 10, inclusive.");
    exitCode = 1;
    return;
  }
  var contents = readFile(path);
  var url = p.toUri(path);
  return renderSourceToCss(contents, url,
      color: color,
      packageResolver: packageResolver,
      indentedSyntax: p.extension(path) == '.sass',
      indentType: indentType,
      indentWidth: indentWidth);
}
