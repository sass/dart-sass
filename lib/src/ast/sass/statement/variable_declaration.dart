// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

class VariableDeclaration implements Statement {
  final String name;

  final Expression expression;

  final bool isGuarded;

  final bool isGlobal;

  final FileSpan span;

  VariableDeclaration(this.name, this.expression, this.span,
      {bool guarded: false, bool global: false})
      : isGuarded = guarded,
        isGlobal = global;

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitVariableDeclaration(this);

  String toString() => "\$$name: $expression;";
}