// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';

/// A `@debug` rule.
///
/// This prints a Sass value for debugging purposes.
class DebugRule implements Statement {
  /// The expression to print.
  final Expression expression;

  final FileSpan span;

  DebugRule(this.expression, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitDebugRule(this);

  String toString() => "@debug $expression;";
}
