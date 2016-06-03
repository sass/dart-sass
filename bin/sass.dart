// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sass/src/parser.dart';
import 'package:sass/src/visitor/css.dart';
import 'package:sass/src/visitor/sass/statement/perform.dart';
import 'package:sass/src/visitor/css/serialize.dart';

void main(List<String> args) {
  var parser = new Parser(new File(args.first).readAsStringSync(),
      url: p.toUri(args.first));
  var cssTree = new PerformVisitor().visitStylesheet(parser.parse());
  print(toCss(cssTree));
}
