// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// A `@return` rule.
///
/// This exits from the current function body with a return value.
class ReturnRule implements Statement {
  /// The value to return from this function.
  final Expression expression;

  final FileSpan span;

  ReturnRule(this.expression, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitReturnRule(this);

  String toString() => "@return $expression;";
}
