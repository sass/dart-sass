// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../visitor.dart';
import 'expression.dart';
import 'node.dart';

class VariableDeclarationNode implements AstNode {
  final String name;

  final Expression expression;

  final bool isGuarded;

  final bool isGlobal;

  final SourceSpan span;

  VariableDeclarationNode(this.name, this.expression, {bool guarded,
          bool global, this.span})
      : isGuarded = guarded,
        isGlobal = global;

  /*=T*/ visit/*<T>*/(AstVisitor/*<T>*/ visitor) =>
      visitor.visitVariableDeclaration(this);

  String toString() => "\$$name: $expression;";
}