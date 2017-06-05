// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:tuple/tuple.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// An `@if` rule.
///
/// This conditionally executes a block of code.
class IfRule implements Statement {
  /// The `@if` and `@else if` clauses.
  ///
  /// The first clause whose expression evaluates to `true` will have its
  /// statements executed. If no expression evaluates to `true`, `lastClause`
  /// will be executed if it's not `null`.
  final List<Tuple2<Expression, List<Statement>>> clauses;

  /// The final, unconditional `@else` clause.
  ///
  /// This is `null` if there is no unconditional `@else`.
  final List<Statement> lastClause;

  final FileSpan span;

  IfRule(Iterable<Tuple2<Expression, Iterable<Statement>>> clauses, this.span,
      {Iterable<Statement> lastClause})
      : clauses = new List.unmodifiable(clauses.map((pair) =>
            new Tuple2(pair.item1, new List.unmodifiable(pair.item2)))),
        lastClause =
            lastClause == null ? null : new List.unmodifiable(lastClause);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIfRule(this);

  String toString() {
    var first = true;
    return clauses.map((pair) {
      var name = first ? 'if' : 'else';
      first = false;
      return '@$name ${pair.item1} {${pair.item2.join(" ")}}';
    }).join(' ');
  }
}
