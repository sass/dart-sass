// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'expression/interpolation.dart';
import 'node.dart';

class StyleRuleNode implements AstNode {
  final InterpolationExpression selector;

  final List<AstNode> children;

  final SourceSpan span;

  // TODO: validate that children only contains variable, at-rule, declaration,
  // or style nodes?
  StyleRuleNode(this.selector, Iterable<AstNode> children, {this.span})
      : children = new List.unmodifiable(children);

  String toString() => "$selector {${children.join("; ")}}";
}