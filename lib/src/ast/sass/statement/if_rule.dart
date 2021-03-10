// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

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
  final ElseClause lastClause;

  final FileSpan span;

  IfRule(Iterable<IfClause> clauses, this.span, {this.lastClause})
      : clauses = List.unmodifiable(clauses);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIfRule(this);

  String toString() {
    var first = true;
    var result = clauses
        .map((clause) =>
            "@${first ? 'if' : 'else if'} {${clause.children.join(' ')}}")
        .join(' ');

    var lastClause = this.lastClause;
    if (lastClause != null) result += " $lastClause";
    return result;
  }
}

/// The superclass of `@if` and `@else` clauses.
abstract class IfRuleClause {
  /// The statements to evaluate if this clause matches.
  final List<Statement> children;

  /// Whether any of [children] is a variable, function, or mixin declaration.
  final bool hasDeclarations;

  IfRuleClause(Iterable<Statement /*!*/ > children)
      : this._(List.unmodifiable(children));

  IfRuleClause._(this.children)
      : hasDeclarations = children.any((child) =>
            child is VariableDeclaration ||
            child is FunctionRule ||
            child is MixinRule ||
            (child is ImportRule &&
                child.imports.any((import) => import is DynamicImport)));
}

/// An `@if` or `@else if` clause in an `@if` rule.
class IfClause extends IfRuleClause {
  /// The expression to evaluate to determine whether to run this rule.
  final Expression expression;

  IfClause(this.expression, Iterable<Statement /*!*/ > children)
      : super(children);

  String toString() => "@if $expression {${children.join(' ')}}";
}

/// An `@else` clause in an `@if` rule.
class ElseClause extends IfRuleClause {
  ElseClause(Iterable<Statement /*!*/ > children) : super(children);

  String toString() => "@else {${children.join(' ')}}";
}
