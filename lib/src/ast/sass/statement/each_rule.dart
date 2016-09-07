// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

class EachRule implements Statement {
  final List<String> variables;

  final Expression list;

  final List<Statement> children;

  final FileSpan span;

  EachRule(Iterable<String> variables, this.list, Iterable<Statement> children,
      this.span)
      : variables = new List.unmodifiable(variables),
        children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitEachRule(this);

  String toString() =>
      "@each ${variables.map((variable) => '\$' + variable).join(', ')} in "
      "$list {${children.join(" ")}}";
}
