// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// A `@while` rule.
///
/// This repeatedly executes a block of code as long as a statement evaluates to
/// `true`.
class WhileRule implements Statement {
  /// The condition that determines whether the block will be executed.
  final Expression condition;

  /// The code to execute repeatedly.
  final List<Statement> children;

  final FileSpan span;

  WhileRule(this.condition, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitWhileRule(this);

  String toString() => "@while $condition {${children.join(" ")}}";
}
