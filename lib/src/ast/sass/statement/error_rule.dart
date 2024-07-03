// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// An `@error` rule.
///
/// This emits an error and stops execution.
///
/// {@category AST}
final class ErrorRule extends Statement {
  /// The expression to evaluate for the error message.
  final Expression expression;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  ErrorRule(this.expression, this.span) : afterTrailing = span.end;

  /// @nodoc
  @internal
  ErrorRule.internal(this.expression, this.span, this.afterTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitErrorRule(this);

  String toString() => "@error $expression;";
}
