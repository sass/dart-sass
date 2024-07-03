// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';
import 'parent.dart';

/// A `@while` rule.
///
/// This repeatedly executes a block of code as long as a statement evaluates to
/// `true`.
///
/// {@category AST}
final class WhileRule extends ParentStatement<List<Statement>> {
  /// The condition that determines whether the block will be executed.
  final Expression condition;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  WhileRule(this.condition, Iterable<Statement> children, this.span)
      : afterTrailing = span.end,
        super(List<Statement>.unmodifiable(children));

  /// @nodoc
  @internal
  WhileRule.internal(this.condition, Iterable<Statement> children, this.span,
      this.afterTrailing)
      : super(List<Statement>.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitWhileRule(this);

  String toString() => "@while $condition {${children.join(" ")}}";
}
