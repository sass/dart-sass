// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_list.dart';
import '../statement.dart';

/// A `@content` rule.
///
/// This is used in a mixin to include statement-level content passed by the
/// caller.
///
/// {@category AST}
final class ContentRule extends Statement {
  /// The arguments pass to this `@content` rule.
  ///
  /// This will be an empty invocation if `@content` has no arguments.
  final ArgumentList arguments;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  ContentRule(this.arguments, this.span) : afterTrailing = span.end;

  /// @nodoc
  @internal
  ContentRule.internal(this.arguments, this.span, this.afterTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitContentRule(this);

  String toString() =>
      arguments.isEmpty ? "@content;" : "@content($arguments);";
}
