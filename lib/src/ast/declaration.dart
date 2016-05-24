// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../visitor/statement.dart';
import 'expression.dart';
import 'expression/interpolation.dart';
import 'statement.dart';

class DeclarationNode implements Statement {
  final InterpolationExpression name;

  final Expression value;

  final SourceSpan span;

  DeclarationNode(this.name, this.value, {this.span});

  /*=T*/ visit/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitDeclaration(this);

  String toString() => "$name: $value;";
}