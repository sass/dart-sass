// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';
import 'parent.dart';

/// An `@each` rule.
///
/// This iterates over values in a list or map.
///
/// {@category AST}
final class EachRule extends ParentStatement<List<Statement>> {
  /// The variables assigned for each iteration.
  final List<String> variables;

  /// The expression whose value this iterates through.
  final Expression list;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  EachRule(
    Iterable<String> variables,
    this.list,
    Iterable<Statement> children,
    this.span,
  )   : variables = List.unmodifiable(variables),
        afterTrailing = span.end,
        super(List.unmodifiable(children));

  /// @nodoc
  @internal
  EachRule.internal(Iterable<String> variables, this.list,
      Iterable<Statement> children, this.span, this.afterTrailing)
      : variables = List.unmodifiable(variables),
        super(List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitEachRule(this);

  String toString() =>
      "@each ${variables.map((variable) => '\$' + variable).join(', ')} in "
      "$list {${children.join(" ")}}";
}
