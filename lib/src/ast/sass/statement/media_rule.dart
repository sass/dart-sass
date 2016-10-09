// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../media_query.dart';
import '../statement.dart';

/// A `@media` rule.
class MediaRule implements Statement {
  /// The queries that select what browsers and conditions this rule targets.
  ///
  /// This is never empty.
  final List<MediaQuery> queries;

  /// The contents of this rule.
  final List<Statement> children;

  final FileSpan span;

  MediaRule(
      Iterable<MediaQuery> queries, Iterable<Statement> children, this.span)
      : queries = new List.unmodifiable(queries),
        children = new List.unmodifiable(children) {
    if (this.queries.isEmpty) {
      throw new ArgumentException("queries may not be empty.");
    }
  }

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitMediaRule(this);

  String toString() => "@media ${queries.join(", ")} {${children.join(" ")}}";
}
