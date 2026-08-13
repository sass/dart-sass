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
final class IfExpression(
  Iterable<(IfConditionExpression?, Expression)> branches,
  @override final FileSpan span,
) extends Expression {
  /// The conditional branches that make up the `if()`.
  ///
  /// A `null` expression indicates an `else` branch that is always evaluated.
  final List<(IfConditionExpression?, Expression)> branches = List.unmodifiable(
    branches,
  );

  this {
    if (this.branches.isEmpty) {
      throw ArgumentError.value(this.branches, "branches", "may not be empty");
    }
  }

  @override
  T accept<T>(ExpressionVisitor<T> visitor) => visitor.visitIfExpression(this);

  @override
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
final class IfConditionParenthesized(
  /// The parenthesized expression.
  final IfConditionExpression expression,
  @override final FileSpan span,
) extends IfConditionExpression {
  /// @nodoc
  @override
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) =>
      (InterpolationBuffer()
            ..writeCharCode($lparen)
            ..addInterpolation(
              expression.toInterpolation(arbitrarySubstitution),
            )
            ..writeCharCode($rparen))
          .interpolation(span);

  @override
  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionParenthesized(this);

  @override
  String toString() => "($expression)";
}

/// A negated condition.
///
/// {@category AST}
final class IfConditionNegation(
  /// The expression negated by this.
  final IfConditionExpression expression,

  @override final FileSpan span,
) extends IfConditionExpression {
  /// @nodoc
  @override
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) =>
      (InterpolationBuffer()
            ..write('not ')
            ..addInterpolation(
              expression.toInterpolation(arbitrarySubstitution),
            ))
          .interpolation(span);

  @override
  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionNegation(this);

  @override
  String toString() => "not $expression";
}

/// A sequence of `and`s or `or`s.
///
/// {@category AST}
final class IfConditionOperation(
  Iterable<IfConditionExpression> expressions,

  /// The operator separating all expressions.
  final BooleanOperator op,
) extends IfConditionExpression {
  /// The expressions conjoined or disjoined by this operation.
  final List<IfConditionExpression> expressions = List.unmodifiable(
    expressions,
  );

  @override
  FileSpan get span => expressions.first.span.expand(expressions.last.span);

  this {
    if (this.expressions.length < 2) {
      throw ArgumentError.value(
        this.expressions,
        "expressions",
        "must have length >= 2",
      );
    }
  }

  /// @nodoc
  @override
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
      buffer.addInterpolation(
        expression.toInterpolation(arbitrarySubstitution),
      );
    }
    return buffer.interpolation(LazyFileSpan(() => span));
  }

  @override
  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionOperation(this);

  @override
  String toString() => expressions.join(" $op ");
}

/// A plain-CSS function-style condition.
///
/// {@category AST}
final class IfConditionFunction(
  /// The name of the function being called.
  final Interpolation name,

  /// The arguments passed to the function call.
  final Interpolation arguments,

  @override final FileSpan span,
) extends IfConditionExpression {
  /// @nodoc
  @override
  @internal
  bool get isArbitrarySubstitution => switch (name.asPlain?.toLowerCase()) {
    "if" || "var" || "attr" => true,
    var str? when str.startsWith("--") => true,
    _ => false,
  };

  /// @nodoc
  @override
  @internal
  Interpolation toInterpolation(AstNode _) =>
      (InterpolationBuffer()
            ..addInterpolation(name)
            ..writeCharCode($lparen)
            ..addInterpolation(arguments)
            ..writeCharCode($rparen))
          .interpolation(span);

  @override
  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionFunction(this);

  @override
  String toString() => "$name($arguments)";
}

/// A Sass condition that will evaluate to true or false at compile time.
///
/// {@category AST}
final class IfConditionSass(
  /// The expression that determines whether this condition matches.
  final Expression expression,

  @override final FileSpan span,
) extends IfConditionExpression {
  /// @nodoc
  @override
  @internal
  Interpolation toInterpolation(AstNode arbitrarySubstitution) =>
      throw MultiSourceSpanFormatException(
        'if() conditions with arbitrary substitutions may not contain sass() '
            'expressions.',
        arbitrarySubstitution.span,
        "arbitrary substitution",
        {span: "sass() expression"},
      );

  @override
  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionSass(this);

  @override
  String toString() => "sass($expression)";
}

/// A chunk of raw text, possibly with interpolations.
///
/// This is used to represent explicit interpolation, as well as whole
/// expressions where arbitrary substitutions are used in place of operators.
///
/// {@category AST}
final class IfConditionRaw(
  /// The text that encompasses this condition.
  final Interpolation text,
) extends IfConditionExpression {
  @override
  FileSpan get span => text.span;

  /// @nodoc
  @override
  @internal
  bool get isArbitrarySubstitution => true;

  /// @nodoc
  @override
  @internal
  Interpolation toInterpolation(AstNode _) => text;

  @override
  T accept<T>(IfConditionExpressionVisitor<T> visitor) =>
      visitor.visitIfConditionRaw(this);

  @override
  String toString() => text.toString();
}
