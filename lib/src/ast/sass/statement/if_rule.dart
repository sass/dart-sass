// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

class IfRule implements Statement {
  final Expression expression;

  final List<Statement> children;

  final FileSpan span;

  IfRule(this.expression, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitIfRule(this);

  String toString() => "@if $expression {${children.join(" ")}}";
}
