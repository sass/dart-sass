// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';
import '../supports_condition.dart';

class SupportsRule implements Statement {
  final SupportsCondition condition;

  final List<Statement> children;

  final FileSpan span;

  SupportsRule(this.condition, Iterable<Statement> children, this.span)
      : children = new List.from(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitSupportsRule(this);

  String toString() => "@supports $condition {${children.join(' ')}}";
}
