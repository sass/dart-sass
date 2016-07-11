// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/css.dart';
import '../parent.dart';
import '../selector.dart';
import 'node.dart';
import 'value.dart';

class CssStyleRule implements CssNode, Parent<CssNode, CssStyleRule> {
  final CssValue<SelectorList> selector;

  final List<CssNode> children;

  final FileSpan span;

  // TODO: validate that children contains only at-rule and declaration nodes?
  CssStyleRule(this.selector, Iterable<CssNode> children, {this.span})
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitStyleRule(this);

  CssStyleRule withChildren(Iterable<CssNode> children) =>
      new CssStyleRule(selector, children, span: span);

  String toString() => "$selector {${children.join(" ")}}";
}