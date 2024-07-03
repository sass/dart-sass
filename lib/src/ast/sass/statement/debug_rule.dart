// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// A `@debug` rule.
///
/// This prints a Sass value for debugging purposes.
///
/// {@category AST}
final class DebugRule extends Statement {
  /// The expression to print.
  final Expression expression;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  DebugRule(this.expression, this.span) : afterTrailing = span.end;

  /// @nodoc
  @internal
  DebugRule.internal(this.expression, this.span, this.afterTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitDebugRule(this);

  String toString() => "@debug $expression;";
}
