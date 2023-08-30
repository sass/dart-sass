// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';

import '../../exception.dart';
import '../../logger.dart';
import '../../parse/scss.dart';
import '../../util/nullable.dart';
import '../../value.dart';
import '../../visitor/interface/expression.dart';
import '../sass.dart';

/// A SassScript expression in a Sass syntax tree.
///
/// {@category AST}
/// {@category Parsing}
@sealed
abstract interface class Expression implements SassNode {
  /// Calls the appropriate visit method on [visitor].
  T accept<T>(ExpressionVisitor<T> visitor);

  /// Parses an expression from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Expression.parse(String contents, {Object? url, Logger? logger}) =>
      ScssParser(contents, url: url, logger: logger).parseExpression();
}

// Use an extension class rather than a method so we don't have to make
// [Extension] a concrete base class for something we'll get rid of anyway once
// we remove the global math functions that make this necessary.
extension ExpressionExtensions on Expression {
  /// Whether this expression can be used in a calculation context.
  ///
  /// @nodoc
  @internal
  bool get isCalculationSafe => accept(_IsCalculationSafeVisitor());
}

// We could use [AstSearchVisitor] to implement this more tersely, but that
// would default to returning `true` if we added a new expression type and
// forgot to update this class.
class _IsCalculationSafeVisitor implements ExpressionVisitor<bool> {
  const _IsCalculationSafeVisitor();

  bool visitBinaryOperationExpression(BinaryOperationExpression node) =>
      (const {
        BinaryOperator.times,
        BinaryOperator.dividedBy,
        BinaryOperator.plus,
        BinaryOperator.minus
      }).contains(node.operator) &&
      (node.left.accept(this) || node.right.accept(this));

  bool visitBooleanExpression(BooleanExpression node) => false;

  bool visitColorExpression(ColorExpression node) => false;

  bool visitFunctionExpression(FunctionExpression node) => true;

  bool visitInterpolatedFunctionExpression(
          InterpolatedFunctionExpression node) =>
      true;

  bool visitIfExpression(IfExpression node) => true;

  bool visitListExpression(ListExpression node) =>
      node.separator == ListSeparator.space &&
      !node.hasBrackets &&
      node.contents.any((expression) =>
          expression is StringExpression &&
          !expression.hasQuotes &&
          !expression.text.isPlain);

  bool visitMapExpression(MapExpression node) => false;

  bool visitNullExpression(NullExpression node) => false;

  bool visitNumberExpression(NumberExpression node) => true;

  bool visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  bool visitSelectorExpression(SelectorExpression node) => false;

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

  bool visitSupportsExpression(SupportsExpression node) => false;

  bool visitUnaryOperationExpression(UnaryOperationExpression node) => false;

  bool visitValueExpression(ValueExpression node) => false;

  bool visitVariableExpression(VariableExpression node) => true;
}
