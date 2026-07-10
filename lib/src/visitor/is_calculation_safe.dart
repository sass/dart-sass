// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import '../util/nullable.dart';
import '../value.dart';
import 'interface/expression.dart';

// We could use [AstSearchVisitor] to implement this more tersely, but that
// would default to returning `true` if we added a new expression type and
// forgot to update this class.

/// A visitor that determines whether an expression is valid in a calculation
/// context.
///
/// This should be used through [Expression.isCalculationSafe].
class IsCalculationSafeVisitor implements ExpressionVisitor<bool> {
  const IsCalculationSafeVisitor();

  @override
  bool visitBinaryOperationExpression(BinaryOperationExpression node) =>
      (const {
        BinaryOperator.times,
        BinaryOperator.dividedBy,
        BinaryOperator.plus,
        BinaryOperator.minus,
      }).contains(node.operator) &&
      node.left.accept(this) &&
      node.right.accept(this);

  @override
  bool visitBooleanExpression(BooleanExpression node) => false;

  @override
  bool visitColorExpression(ColorExpression node) => false;

  @override
  bool visitFunctionExpression(FunctionExpression node) => true;

  @override
  bool visitIfExpression(IfExpression node) => true;

  @override
  bool visitInterpolatedFunctionExpression(
    InterpolatedFunctionExpression node,
  ) =>
      true;

  @override
  bool visitLegacyIfExpression(LegacyIfExpression node) => true;

  @override
  bool visitListExpression(ListExpression node) =>
      node.separator == ListSeparator.space &&
      !node.hasBrackets &&
      node.contents.length > 1 &&
      node.contents.every((expression) => expression.accept(this));

  @override
  bool visitMapExpression(MapExpression node) => false;

  @override
  bool visitNullExpression(NullExpression node) => false;

  @override
  bool visitNumberExpression(NumberExpression node) => true;

  @override
  bool visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  @override
  bool visitSelectorExpression(SelectorExpression node) => false;

  @override
  bool visitStringExpression(StringExpression node) {
    if (node.hasQuotes) return false;

    // Exclude non-identifier constructs that are parsed as [StringExpression]s.
    // We could just check if they parse as valid identifiers, but this is
    // cheaper.
    var text = node.text.initialPlain;
    return
        // !important
        !text.startsWith("!") &&
            // ID-style identifiers
            !text.startsWith("#") &&
            // Unicode ranges
            text.codeUnitAtOrNull(1) != $plus &&
            // url()
            text.codeUnitAtOrNull(3) != $lparen;
  }

  @override
  bool visitSupportsExpression(SupportsExpression node) => false;

  @override
  bool visitUnaryOperationExpression(UnaryOperationExpression node) => false;

  @override
  bool visitValueExpression(ValueExpression node) => false;

  @override
  bool visitVariableExpression(VariableExpression node) => true;
}
