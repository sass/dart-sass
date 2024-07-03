// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// A `@warn` rule.
///
/// This prints a Sass value—usually a string—to warn the user of something.
///
/// {@category AST}
final class WarnRule extends Statement {
  /// The expression to print.
  final Expression expression;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  WarnRule(this.expression, this.span) : afterTrailing = span.end;

  /// @nodoc
  @internal
  WarnRule.internal(this.expression, this.span, this.afterTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitWarnRule(this);

  String toString() => "@warn $expression;";
}
