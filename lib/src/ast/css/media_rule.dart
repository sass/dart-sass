// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/css.dart';
import '../parent.dart';
import 'node.dart';

class CssMediaRule implements CssNode, Parent<CssNode, CssMediaRule> {
  final List<CssMediaQuery> queries;

  final List<CssNode> children;

  final FileSpan span;

  // TODO: validate that children contains only at-rule and style rule nodes?
  CssMediaRule(Iterable<CssMediaQuery> queries, Iterable<CssNode> children,
      {this.span})
      : queries = new List.unmodifiable(queries),
        children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitMediaRule(this);

  CssMediaRule withChildren(Iterable<CssNode> children) =>
      new CssMediaRule(queries, children, span: span);

  String toString() => "@media ${queries.join(", ")} {${children.join(" ")}}";
}
