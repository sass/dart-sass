// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/statement.dart';
import 'argument_declaration.dart';
import 'statement.dart';

class FunctionDeclaration implements Statement {
  final String name;

  final ArgumentDeclaration arguments;

  final List<Statement> children;

  final FileSpan span;

  FunctionDeclaration(this.name, this.arguments, Iterable<Statement> children,
      {this.span})
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitFunctionDeclaration(this);

  String toString() => "@function $name($arguments) {${children.join(' ')}}";
}
