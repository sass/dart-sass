// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

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
final class EachRule(
  Iterable<String> variables,

  /// The expression whose value this iterates through.
  final Expression list,
  Iterable<Statement> children,
  @override final FileSpan span,
) extends ParentStatement<List<Statement>> {
  /// The variables assigned for each iteration.
  final List<String> variables = List.unmodifiable(variables);

  this : super(List.unmodifiable(children));

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitEachRule(this);

  @override
  String toString() =>
      "@each ${variables.map((variable) => '\$$variable').join(', ')} in "
      "$list {${children.join(" ")}}";
}
