// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

class ForRule implements Statement {
  final String variable;

  final Expression from;

  final Expression to;

  final bool isExclusive;

  final List<Statement> children;

  final FileSpan span;

  ForRule(this.variable, this.from, this.to, Iterable<Statement> children,
      this.span,
      {bool exclusive: true})
      : children = new List.unmodifiable(children),
        isExclusive = exclusive;

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitForRule(this);

  String toString() =>
      "@for \$$variable from $from ${isExclusive ? 'to' : 'through'} $to "
      "{${children.join(" ")}}";
}
