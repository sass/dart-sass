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
///
/// {@category AST}
final class ForRule(
  /// The name of the variable that will contain the index value.
  final String variable,

  /// The expression for the start index.
  final Expression from,

  /// The expression for the end index.
  final Expression to,
  Iterable<Statement> children,
  @override final FileSpan span, {
  bool exclusive = true,
}) extends ParentStatement<List<Statement>> {
  /// Whether [to] is exclusive.
  final bool isExclusive = exclusive;

  this : super(List.unmodifiable(children));

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitForRule(this);

  @override
  String toString() =>
      "@for \$$variable from $from ${isExclusive ? 'to' : 'through'} $to "
      "{${children.join(" ")}}";
}
