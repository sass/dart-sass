// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

class AtRule implements Statement {
  final String name;

  final Interpolation value;

  final List<Statement> children;

  final FileSpan span;

  AtRule(this.name, this.span, {this.value, Iterable<Statement> children})
      : children = children == null ? null : new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitAtRule(this);

  String toString() {
    var buffer = new StringBuffer("@$name");
    if (value != null) buffer.write(" $value");
    return children == null ? "$buffer;" : "$buffer {${children.join(" ")}}";
  }
}
