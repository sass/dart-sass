// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/css.dart';
import 'node.dart';
import 'value.dart';

class CssAtRule implements CssNode {
  final String name;

  final CssValue<String> value;

  final List<CssNode> children;

  final FileSpan span;

  // TODO: validate that children contains only at-rule and declaration nodes?
  CssAtRule(this.name, {this.value, Iterable<CssNode> children, this.span})
      : children = children == null ? null : new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitAtRule(this);

  String toString() {
    var buffer = new StringBuffer("@$name");
    if (value != null) buffer.write(" $value");
    return children == null ? "$buffer;" : "$buffer {${children.join(" ")}}";
  }
}