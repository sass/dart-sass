// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'media_query.dart';
import 'node.dart';

/// A plain CSS `@media` rule.
class CssMediaRule extends CssParentNode {
  /// The queries for this rule.
  ///
  /// This is never empty.
  final List<CssMediaQuery> queries;

  final FileSpan span;

  CssMediaRule(Iterable<CssMediaQuery> queries, this.span)
      : queries = new List.unmodifiable(queries) {
    if (queries.isEmpty) {
      throw new ArgumentError.value(queries, "queries", "may not be empty.");
    }
  }

  T accept<T>(CssVisitor<T> visitor) => visitor.visitMediaRule(this);

  CssMediaRule copyWithoutChildren() => new CssMediaRule(queries, span);
}
