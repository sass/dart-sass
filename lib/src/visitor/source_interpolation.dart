// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../ast/node.dart';
import '../ast/sass.dart';
import '../interpolation_buffer.dart';
import '../util/span.dart';
import 'interface/expression.dart';
import 'interface/if_condition_expression.dart';

/// A visitor that builds an [Interpolation] that evaluates to the same text as
/// the given expression.
///
/// This should be used through [Expression.asInterpolation].
class SourceInterpolationVisitor
    implements ExpressionVisitor<void>, IfConditionExpressionVisitor<void> {
  /// The buffer to which content is added each time this visitor visits an
  /// expression.
  ///
  /// This is set to null if the visitor encounters a node that's not valid CSS
  /// with interpolations.
  InterpolationBuffer? buffer = InterpolationBuffer();

  void visitBinaryOperationExpression(BinaryOperationExpression node) =>
      buffer = null;

  void visitBooleanExpression(BooleanExpression node) => buffer = null;

  void visitColorExpression(ColorExpression node) =>
      buffer?.write(node.span.text);

  void visitFunctionExpression(FunctionExpression node) => buffer = null;

  void visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) {
    buffer?.addInterpolation(node.name);
    _visitArguments(node.arguments);
  }

  /// Visits the positional arguments in [arguments] with [visitor], if it's
  /// valid interpolated plain CSS.
  void _visitArguments(ArgumentList arguments) {
    if (arguments.named.isNotEmpty || arguments.rest != null) return;

    if (arguments.positional.isEmpty) {
      buffer?.write(arguments.span.text);
      return;
    }

    buffer?.write(arguments.span.before(arguments.positional.first.span).text);
    _writeListAndBetween(arguments.positional, (node) => node.accept(this));
    buffer?.write(arguments.span.after(arguments.positional.last.span).text);
  }

  void visitIfExpression(IfExpression node) {
    FileSpan? lastSpan;
    for (var (condition, expression) in node.branches) {
      var firstSpan = condition?.span ?? expression.span;
      buffer?.write(
          (lastSpan?.between(firstSpan) ?? node.span.before(firstSpan)).text);

      if (condition != null) {
        condition.accept(this);
        buffer?.write(condition.span.between(expression.span).text);
      }

      expression.accept(this);
      lastSpan = expression.span;
    }
  }

  void visitIfConditionParenthesized(IfConditionParenthesized node) {
    buffer?.write(node.span.before(node.expression.span).text);
    node.expression.accept(this);
    buffer?.write(node.span.after(node.expression.span).text);
  }

  void visitIfConditionNegation(IfConditionNegation node) {
    buffer?.write(node.span.before(node.expression.span).text);
    node.expression.accept(this);
  }

  void visitIfConditionOperation(IfConditionOperation node) {
    _writeListAndBetween(node.expressions, (node) => node.accept(this));
  }

  void visitIfConditionFunction(IfConditionFunction node) {
    buffer?.addInterpolation(node.name);
    buffer?.write(node.name.span.between(node.arguments.span).text);
    buffer?.addInterpolation(node.arguments);
    buffer?.write(node.span.after(node.arguments.span).text);
  }

  void visitIfConditionSass(IfConditionSass node) {
    buffer = null;
  }

  void visitIfConditionRaw(IfConditionRaw node) {
    buffer?.addInterpolation(node.text);
  }

  void visitLegacyIfExpression(LegacyIfExpression node) => buffer = null;

  void visitListExpression(ListExpression node) {
    if (node.contents.length <= 1 && !node.hasBrackets) {
      buffer = null;
      return;
    }

    if (node.hasBrackets && node.contents.isEmpty) {
      buffer?.write(node.span.text);
      return;
    }

    if (node.hasBrackets) {
      buffer?.write(node.span.before(node.contents.first.span).text);
    }
    _writeListAndBetween(node.contents, (node) => node.accept(this));

    if (node.hasBrackets) {
      buffer?.write(node.span.after(node.contents.last.span).text);
    }
  }

  void visitMapExpression(MapExpression node) => buffer = null;

  void visitNullExpression(NullExpression node) => buffer = null;

  void visitNumberExpression(NumberExpression node) =>
      buffer?.write(node.span.text);

  void visitParenthesizedExpression(ParenthesizedExpression node) =>
      buffer = null;

  void visitSelectorExpression(SelectorExpression node) => buffer = null;

  void visitStringExpression(StringExpression node) {
    if (node.text.isPlain) {
      buffer?.write(node.span.text);
      return;
    }

    for (var i = 0; i < node.text.contents.length; i++) {
      var span = node.text.spanForElement(i);
      switch (node.text.contents[i]) {
        case Expression expression:
          if (i == 0) buffer?.write(node.span.before(span).text);
          buffer?.add(expression, span);
          if (i == node.text.contents.length - 1) {
            buffer?.write(node.span.after(span).text);
          }

        case _:
          buffer?.write(span);
      }
    }
  }

  void visitSupportsExpression(SupportsExpression node) => buffer = null;

  void visitUnaryOperationExpression(UnaryOperationExpression node) =>
      buffer = null;

  void visitValueExpression(ValueExpression node) => buffer = null;

  void visitVariableExpression(VariableExpression node) => buffer = null;

  /// Visits each expression in [nodes] with [visit], and writes whatever text
  /// is between them to [buffer].
  void _writeListAndBetween<T extends AstNode>(
      List<T> nodes, void Function(T) visit) {
    FileSpan? lastSpan;
    for (var node in nodes) {
      if (lastSpan != null) {
        buffer?.write(lastSpan.between(node.span).text);
      }
      visit(node);
      if (buffer == null) return;
      lastSpan = node.span;
    }
  }
}
