// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

class WhileRule implements Statement {
  final Expression condition;

  final List<Statement> children;

  final FileSpan span;

  WhileRule(this.condition, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitWhileRule(this);

  String toString() => "@while $condition {${children.join(" ")}}";
}
