// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

class Return implements Statement {
  final Expression expression;

  final FileSpan span;

  Return(this.expression, {this.span});

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitReturn(this);

  String toString() => "@return $expression;";
}
