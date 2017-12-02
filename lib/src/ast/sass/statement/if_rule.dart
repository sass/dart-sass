// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';
import 'function_rule.dart';
import 'mixin_rule.dart';
import 'variable_declaration.dart';

/// An `@if` rule.
///
/// This conditionally executes a block of code.
class IfRule implements Statement {
  /// The `@if` and `@else if` clauses.
  ///
  /// The first clause whose expression evaluates to `true` will have its
  /// statements executed. If no expression evaluates to `true`, `lastClause`
  /// will be executed if it's not `null`.
  final List<IfClause> clauses;

  /// The final, unconditional `@else` clause.
  ///
  /// This is `null` if there is no unconditional `@else`.
  final IfClause lastClause;

  final FileSpan span;

  IfRule(Iterable<IfClause> clauses, this.span, {this.lastClause})
      : clauses = new List.unmodifiable(clauses) {
    assert(clauses.every((clause) => clause.expression != null));
    assert(lastClause?.expression == null);
  }

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIfRule(this);

  String toString() {
    var first = true;
    return clauses.map((clause) {
      var name = first ? 'if' : 'else';
      first = false;
      return '@$name ${clause.expression} {${clause.children.join(" ")}}';
    }).join(' ');
  }
}

/// A single clause in an `@if` rule.
class IfClause {
  /// The expression to evaluate to determine whether to run this rule, or
  /// `null` if this is the final unconditional `@else` clause.
  final Expression expression;

  /// The statements to evaluate if this clause matches.
  final List<Statement> children;

  /// Whether any of [children] is a variable, function, or mixin declaration.
  final bool hasDeclarations;

  IfClause(Expression expression, Iterable<Statement> children)
      : this._(expression, new List.unmodifiable(children));

  IfClause.last(Iterable<Statement> children)
      : this._(null, new List.unmodifiable(children));

  IfClause._(this.expression, this.children)
      : hasDeclarations = children.any((child) =>
            child is VariableDeclaration ||
            child is FunctionRule ||
            child is MixinRule);

  String toString() =>
      (expression == null ? "@else" : "@if $expression") +
      " {${children.join(' ')}}";
}
