// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../media_query.dart';
import '../media_rule.dart';
import 'node.dart';

/// A modifiable version of [CssMediaRule] for use in the evaluation step.
class ModifiableCssMediaRule extends ModifiableCssParentNode
    implements CssMediaRule {
  final List<CssMediaQuery> queries;
  final FileSpan span;

  ModifiableCssMediaRule(Iterable<CssMediaQuery> queries, this.span)
      : queries = List.unmodifiable(queries) {
    if (queries.isEmpty) {
      throw ArgumentError.value(queries, "queries", "may not be empty.");
    }
  }

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssMediaRule(this);

  ModifiableCssMediaRule copyWithoutChildren() =>
      ModifiableCssMediaRule(queries, span);
}
