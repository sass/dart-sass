// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../import/dynamic.dart';
import '../statement.dart';
import 'function_rule.dart';
import 'import_rule.dart';
import 'mixin_rule.dart';
import 'variable_declaration.dart';

/// An `@if` rule.
///
/// This conditionally executes a block of code.
///
/// {@category AST}
final class IfRule extends Statement {
  /// The `@if` and `@else if` clauses.
  ///
  /// The first clause whose expression evaluates to `true` will have its
  /// statements executed. If no expression evaluates to `true`, `lastClause`
  /// will be executed if it's not `null`.
  final List<IfClause> clauses;

  /// The final, unconditional `@else` clause.
  ///
  /// This is `null` if there is no unconditional `@else`.
  final ElseClause? lastClause;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  IfRule(Iterable<IfClause> clauses, this.span, {this.lastClause})
      : clauses = List.unmodifiable(clauses),
        afterTrailing = span.end;

  /// @nodoc
  @internal
  IfRule.internal(Iterable<IfClause> clauses, this.span, this.afterTrailing,
      {this.lastClause})
      : clauses = List.unmodifiable(clauses);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIfRule(this);

  String toString() {
    var result = clauses
        .mapIndexed(
          (index, clause) =>
              "@${index == 0 ? 'if' : 'else if'} ${clause.expression} "
              "{${clause.children.join(' ')}}",
        )
        .join(' ');

    var lastClause = this.lastClause;
    if (lastClause != null) result += " $lastClause";
    return result;
  }
}

/// The superclass of `@if` and `@else` clauses.
///
/// {@category AST}
sealed class IfRuleClause {
  /// The statements to evaluate if this clause matches.
  final List<Statement> children;

  /// Whether any of [children] is a variable, function, or mixin declaration.
  ///
  /// @nodoc
  @internal
  final bool hasDeclarations;

  /// The span that covers this specific conditional clause.
  final FileSpan span;

  /// The location after any trailing whitespace and comments following this
  /// clause that aren't parsed as their own statements.
  ///
  /// This is used to generate PostCSS "raws", strings that are used to
  /// reconstruct or modify the exact formatting of the original stylesheet.
  ///
  /// :nodoc:
  @internal
  final FileLocation afterTrailing;

  /// @nodoc
  @internal
  IfRuleClause(Iterable<Statement> children, FileSpan span, [FileLocation? afterTrailing])
      : this._(List.unmodifiable(children), span, afterTrailing ?? span.end);

  IfRuleClause._(this.children, this.span, this.afterTrailing)
      : hasDeclarations = children.any((child) => switch (child) {
              VariableDeclaration() || FunctionRule() || MixinRule() => true,
              ImportRule(:var imports) =>
                imports.any((import) => import is DynamicImport),
              _ => false
            });
}

/// An `@if` or `@else if` clause in an `@if` rule.
///
/// {@category AST}
final class IfClause extends IfRuleClause {
  /// The expression to evaluate to determine whether to run this rule.
  final Expression expression;

  IfClause(this.expression, super.children, super.span);

  /// :nodoc:
  @internal
  IfClause.internal(this.expression, super.children, super.span, super.afterTrailing);

  String toString() => "@if $expression {${children.join(' ')}}";
}

/// An `@else` clause in an `@if` rule.
///
/// {@category AST}
final class ElseClause extends IfRuleClause {
  ElseClause(super.children, super.span);

  /// :nodoc:
  @internal
  ElseClause.internal(super.children, super.span, super.afterTrailing);

  String toString() => "@else {${children.join(' ')}}";
}
