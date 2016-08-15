// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/statement.dart';
import 'statement.dart';

class MediaRule implements Statement {
  final List<MediaQuery> queries;

  final List<Statement> children;

  final FileSpan span;

  MediaRule(Iterable<MediaQuery> queries, Iterable<Statement> children,
      {this.span})
      : queries = new List.unmodifiable(queries),
        children = new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitMediaRule(this);

  String toString() => "@media ${queries.join(", ")} {${children.join(" ")}}";
}
