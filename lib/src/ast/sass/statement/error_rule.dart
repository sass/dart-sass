// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// An `@error` rule.
///
/// This emits an error and stops execution.
class ErrorRule implements Statement {
  /// The expression to evaluate for the error message.
  final Expression expression;

  final FileSpan span;

  ErrorRule(this.expression, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitErrorRule(this);

  String toString() => "@error $expression;";
}
