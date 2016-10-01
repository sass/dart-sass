// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// An `@if` rule.
///
/// This conditionally executes a block of code.
class IfRule implements Statement {
  /// The expression to evaluate when determining whether to evaluate the code.
  final Expression expression;

  /// The children to evaluate if [expression] produces a truthy value.
  final List<Statement> children;

  final FileSpan span;

  IfRule(this.expression, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitIfRule(this);

  String toString() => "@if $expression {${children.join(" ")}}";
}
