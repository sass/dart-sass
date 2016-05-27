// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../utils.dart';
import '../../visitor/sass/statement.dart';
import 'expression.dart';
import 'expression/interpolation.dart';
import 'statement.dart';

class Declaration implements Statement {
  final InterpolationExpression name;

  final Expression value;

  SourceSpan get span => spanForList([name, value]);

  Declaration(this.name, this.value);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitDeclaration(this);

  String toString() => "$name: $value;";
}