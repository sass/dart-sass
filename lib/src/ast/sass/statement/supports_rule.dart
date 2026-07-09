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
final class SupportsRule extends ParentStatement<List<Statement>> {
  /// The condition that selects what browsers this rule targets.
  final SupportsCondition condition;

  @override
  final FileSpan span;

  SupportsRule(this.condition, Iterable<Statement> children, this.span)
      : super(List.unmodifiable(children));

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitSupportsRule(this);

  @override
  String toString() => "@supports $condition {${children.join(' ')}}";
}
