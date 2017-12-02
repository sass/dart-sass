// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';
import 'parent.dart';

/// A `@for` rule.
///
/// This iterates a set number of times.
class ForRule extends ParentStatement {
  /// The name of the variable that will contain the index value.
  final String variable;

  /// The expression for the start index.
  final Expression from;

  /// The expression for the end index.
  final Expression to;

  /// Whether [to] is exclusive.
  final bool isExclusive;

  final FileSpan span;

  ForRule(this.variable, this.from, this.to, Iterable<Statement> children,
      this.span,
      {bool exclusive: true})
      : isExclusive = exclusive,
        super(new List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitForRule(this);

  String toString() =>
      "@for \$$variable from $from ${isExclusive ? 'to' : 'through'} $to "
      "{${children.join(" ")}}";
}
