// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../visitor.dart';
import 'node.dart';

class StylesheetNode implements AstNode {
  final List<AstNode> children;

  final SourceSpan span;

  StylesheetNode(Iterable<AstNode> children, {this.span})
      : children = new List.unmodifiable(children);

  /*=T*/ visit/*<T>*/(AstVisitor/*<T>*/ visitor) =>
      visitor.visitStylesheet(this);

  String toString() => children.map((child) => "$child").join(" ");
}