// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/sass/statement.dart';
import '../parent.dart';
import 'statement.dart';

class Stylesheet implements Statement, Parent<Statement, Stylesheet> {
  final List<Statement> children;

  final FileSpan span;

  Stylesheet(Iterable<Statement> children, {this.span})
      : children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitStylesheet(this);

  Stylesheet withChildren(Iterable<Statement> children) =>
      new Stylesheet(children, span: span);

  String toString() => children.join(" ");
}