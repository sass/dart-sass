// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// A `@return` rule.
///
/// This exits from the current function body with a return value.
///
/// {@category AST}
final class ReturnRule extends Statement {
  /// The value to return from this function.
  final Expression expression;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  ReturnRule(this.expression, this.span) : afterTrailing = span.end;

  /// @nodoc
  @internal
  ReturnRule.internal(this.expression, this.span, this.afterTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitReturnRule(this);

  String toString() => "@return $expression;";
}
