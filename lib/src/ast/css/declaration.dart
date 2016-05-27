// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../value.dart';
import '../../visitor/css.dart';
import 'node.dart';
import 'value.dart';

class CssDeclaration implements CssNode {
  final CssValue<String> name;

  final CssValue<Value> value;

  final SourceSpan span;

  CssDeclaration(this.name, this.value, {this.span});

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitDeclaration(this);

  String toString() => "$name: $value;";
}