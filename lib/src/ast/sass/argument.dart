// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'expression.dart';
import 'node.dart';

class Argument implements SassNode {
  final String name;

  final Expression defaultValue;

  final FileSpan span;

  Argument(this.name, {this.defaultValue, this.span});

  String toString() => defaultValue == null ? name : "$name: $defaultValue";
}
