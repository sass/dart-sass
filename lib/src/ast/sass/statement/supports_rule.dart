// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';
import '../supports_condition.dart';
import 'parent.dart';

/// A `@supports` rule.
///
/// {@category AST}
final class SupportsRule(
  /// The condition that selects what browsers this rule targets.
  final SupportsCondition condition,
  Iterable<Statement> children,
  @override final FileSpan span,
) extends ParentStatement<List<Statement>> {
  this : super(List.unmodifiableOf(children));

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitSupportsRule(this);

  @override
  String toString() => "@supports $condition {${children.join(' ')}}";
}
