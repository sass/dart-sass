// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../ast/node.dart';
import '../../../ast/sass.dart';
import '../../../interpolation_buffer.dart';
import '../../../util/lazy_file_span.dart';
import '../../../visitor/interface/expression.dart';
import '../../../visitor/interface/if_condition_expression.dart';

/// A CSS `if()` expression.
///
/// In addition to supporting the plain-CSS syntax, this supports a `sass()`
/// condition that evaluates SassScript expressions.
///
/// {@category AST}
final class IfExpression extends Expression {
  /// The conditional branches that make up the `if()`.
  ///
  /// A `null` expression indicates an `else` branch that is always evaluated.
  final List<(IfConditionExpression?, Expression)> branches;

  final FileSpan span;

  IfExpression(
      Iterable<(IfConditionExpression?, Expression)> branches, this.span)
      : branches = List.unmodifiable(branches) {
    if (this.branches.isEmpty) {
      throw ArgumentError.value(this.branches, "branches", "may not be empty");
    }
  }

  T accept<T>(ExpressionVisitor<T> visitor) => visitor.visitIfExpression(this);

  String toString() {
    var buffer = StringBuffer("if(");
    var first = true;
    for (var (condition, expression) in branches) {
      if (first) {
        first = false;
      } else {
        buffer.write("; ");
      }

      buffer.write(condition ?? "else");
      buffer.write(": ");
      buffer.write(expression);
    }
    buffer.writeCharCode($rparen);
    return buffer.toString();
  }
}

/// The parent class of conditions in an [IfExpression].
///
/// {@category AST}
sealed class IfConditionExpression implements SassNode {
  /// Returns whether this is an arbitrary substitution expression which may be
  /// replaced with multiple tokens at evaluation or render time.
  ///
  /// @nodoc
  @internal
  bool get isArbitrarySubstitution => false;

  /// Converts this expression into an interpolation that produces the same
  /// value.
  ///
  /// Throws a [SourceSpanFormatException] if this contains an
  /// [IfConditionSass]. [arbitrarySubstitution]'s span is used for this error.
  ///
  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution);

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(IfConditionExpressionVisitor<T> visitor);
}

/// A parenthesized condition.
///
/// {@category AST}
final class IfConditionParenthesized extends IfConditionExpression {
  /// The parenthesized expression.
  final IfConditionExpression expression;

  final FileSpan span;

  IfConditionParenthesized(this.expression, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) =>
      (InterpolationBuffer()
            ..writeCharCode($lparen)
            ..addInterpolation(
                expression.toInterpolation(arbitrarySubstitution))
            ..writeCharCode($rparen))
          .interpolation(span);

  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionParenthesized(this);

  String toString() => "($expression)";
}

/// A negated condition.
///
/// {@category AST}
final class IfConditionNegation extends IfConditionExpression {
  /// The expression negated by this.
  final IfConditionExpression expression;

  final FileSpan span;

  IfConditionNegation(this.expression, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) =>
      (InterpolationBuffer()
            ..write('not ')
            ..addInterpolation(
                expression.toInterpolation(arbitrarySubstitution)))
          .interpolation(span);

  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionNegation(this);

  String toString() => "not $expression";
}

/// A sequence of `and`s or `or`s.
///
/// {@category AST}
final class IfConditionOperation extends IfConditionExpression {
  /// The expressions conjoined or disjoined by this operation.
  final List<IfConditionExpression> expressions;

  final BooleanOperator op;

  FileSpan get span => expressions.first.span.expand(expressions.last.span);

  IfConditionOperation(Iterable<IfConditionExpression> expressions, this.op)
      : expressions = List.unmodifiable(expressions) {
    if (this.expressions.length < 2) {
      throw ArgumentError.value(
          this.expressions, "expressions", "must have length >= 2");
    }
  }

  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) {
    var buffer = InterpolationBuffer();
    var first = true;
    for (var expression in expressions) {
      if (first) {
        first = false;
      } else {
        buffer.write(' $op ');
      }
      buffer
          .addInterpolation(expression.toInterpolation(arbitrarySubstitution));
    }
    return buffer.interpolation(LazyFileSpan(() => span));
  }

  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionOperation(this);

  String toString() => expressions.join(" $op ");
}

/// A plain-CSS function-style condition.
///
/// {@category AST}
final class IfConditionFunction extends IfConditionExpression {
  /// The name of the function being called.
  final Interpolation name;

  /// The arguments passed to the function call.
  final Interpolation arguments;

  final FileSpan span;

  /// @nodoc
  @internal
  bool get isArbitrarySubstitution => switch (name.asPlain?.toLowerCase()) {
        "if" || "var" || "attr" => true,
        var str? when str.startsWith("--") => true,
        _ => false,
      };

  IfConditionFunction(this.name, this.arguments, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode _) => (InterpolationBuffer()
        ..addInterpolation(name)
        ..writeCharCode($lparen)
        ..addInterpolation(arguments)
        ..writeCharCode($rparen))
      .interpolation(span);

  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionFunction(this);

  String toString() => "$name($arguments)";
}

/// A Sass condition that will evaluate to true or false at compile time.
///
/// {@category AST}
final class IfConditionSass extends IfConditionExpression {
  /// The expression that determines whether this condition matches.
  final Expression expression;

  final FileSpan span;

  IfConditionSass(this.expression, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) =>
      throw MultiSourceSpanFormatException(
          'if() conditions with arbitrary substitutions may not contain sass() '
              'expressions.',
          arbitrarySubstitution.span,
          "arbitrary substitution",
          {span: "sass() expression"});

  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionSass(this);

  String toString() => "sass($expression)";
}

/// A chunk of raw text, possibly with interpolations.
///
/// This is used to represent explicit interpolation, as well as whole
/// expressions where arbitrary substitutions are used in place of operators.
///
/// {@category AST}
final class IfConditionRaw extends IfConditionExpression {
  /// The text that encompasses this condition.
  final Interpolation text;

  FileSpan get span => text.span;

  /// @nodoc
  @internal
  bool get isArbitrarySubstitution => true;

  IfConditionRaw(this.text);

  /// @nodoc
  @internal
  Interpolation toInterpolation(AstNode _) => text;

  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionRaw(this);

  String toString() => text.toString();
}
