// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/statement.dart';
import 'expression.dart';
import 'statement.dart';

class VariableDeclaration implements Statement {
  final String name;

  final Expression expression;

  final bool isGuarded;

  final bool isGlobal;

  final SourceSpan span;

  VariableDeclaration(this.name, this.expression, {bool guarded,
          bool global, this.span})
      : isGuarded = guarded,
        isGlobal = global;

  /*=T*/ visit/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitVariableDeclaration(this);

  String toString() => "\$$name: $expression;";
}