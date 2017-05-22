// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../sync_package_resolver.dart';
import '../visitor/perform.dart';
import '../visitor/serialize.dart';

String renderSourceToCss(String contents, Uri url,
    {bool color: false,
    SyncPackageResolver packageResolver,
    bool indentedSyntax: false,
    String indentType: 'space',
    int indentWidth: 2}) {
  var sassTree = indentedSyntax
      ? new Stylesheet.parseSass(contents, url: url, color: color)
      : new Stylesheet.parseScss(contents, url: url, color: color);
  var cssTree =
      evaluate(sassTree, color: color, packageResolver: packageResolver);
  return toCss(cssTree, indentType: indentType, indentWidth: indentWidth);
}
