// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/css.dart';
import 'node.dart';

class CssStylesheet implements CssNode {
  final List<CssNode> children;

  final FileSpan span;

  CssStylesheet(Iterable<CssNode> children, {this.span})
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitStylesheet(this);

  String toString() => children.join(" ");
}