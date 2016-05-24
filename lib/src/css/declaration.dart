// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../value/identifier.dart';
import 'node.dart';
import 'value.dart';

class CssDeclaration implements CssNode {
  final CssValue<Identifier> name;

  final CssValue value;

  final SourceSpan span;

  CssDeclaration(this.name, this.value, {this.span});

  String toString() => "$name: $value;";
}