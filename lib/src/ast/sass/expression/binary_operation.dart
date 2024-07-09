// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../util/span.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'list.dart';

/// A binary operator, as in `1 + 2` or `$this and $other`.
///
/// {@category AST}
final class BinaryOperationExpression extends Expression {
  /// The operator being invoked.
  final BinaryOperator operator;

  /// The left-hand operand.
  final Expression left;

  /// The right-hand operand.
  final Expression right;

  /// Whether this is a [BinaryOperator.dividedBy] operation that may be
  /// interpreted as slash-separated numbers.
  ///
  /// @nodoc
  @internal
  final bool allowsSlash;

  FileSpan get span {
    // Avoid creating a bunch of intermediate spans for multiple binary
    // expressions in a row by moving to the left- and right-most expressions.
    var left = this.left;
    while (left is BinaryOperationExpression) {
      left = left.left;
    }

    var right = this.right;
    while (right is BinaryOperationExpression) {
      right = right.right;
    }
    return left.span.expand(right.span);
  }

  /// Returns the span that covers only [operator].
  ///
  /// @nodoc
  @internal
  FileSpan get operatorSpan => left.span.file == right.span.file &&
          left.span.end.offset < right.span.start.offset
      ? left.span.file
          .span(left.span.end.offset, right.span.start.offset)
          .trim()
      : span;

  BinaryOperationExpression(this.operator, this.left, this.right)
      : allowsSlash = false;

  /// Creates a [BinaryOperator.dividedBy] operation that may be interpreted as
  /// slash-separated numbers.
  ///
  /// @nodoc
  @internal
  BinaryOperationExpression.slash(this.left, this.right)
      : operator = BinaryOperator.dividedBy,
        allowsSlash = true;

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitBinaryOperationExpression(this);

  String toString() {
    var buffer = StringBuffer();

    // dart-lang/language#3064 and #3062 track potential ways of making this
    // cleaner.
    var leftNeedsParens = switch (left) {
      BinaryOperationExpression(operator: BinaryOperator(:var precedence)) =>
        precedence < operator.precedence,
      ListExpression(hasBrackets: false, contents: [_, _, ...]) => true,
      _ => false
    };
    if (leftNeedsParens) buffer.writeCharCode($lparen);
    buffer.write(left);
    if (leftNeedsParens) buffer.writeCharCode($rparen);

    buffer.writeCharCode($space);
    buffer.write(operator.operator);
    buffer.writeCharCode($space);

    var right = this.right; // Hack to make analysis work.
    var rightNeedsParens = switch (right) {
      BinaryOperationExpression(:var operator) =>
        operator.precedence <= this.operator.precedence &&
            !(operator == this.operator && operator.isAssociative),
      ListExpression(hasBrackets: false, contents: [_, _, ...]) => true,
      _ => false
    };
    if (rightNeedsParens) buffer.writeCharCode($lparen);
    buffer.write(right);
    if (rightNeedsParens) buffer.writeCharCode($rparen);

    return buffer.toString();
  }
}

/// A binary operator constant.
///
/// {@category AST}
enum BinaryOperator {
  // Note: When updating these operators, also update
  // pkg/sass-parser/lib/src/expression/binary-operation.ts.

  /// The Microsoft equals operator, `=`.
  singleEquals('single equals', '=', 0),

  /// The disjunction operator, `or`.
  or('or', 'or', 1, associative: true),

  /// The conjunction operator, `and`.
  and('and', 'and', 2, associative: true),

  /// The equality operator, `==`.
  equals('equals', '==', 3),

  /// The inequality operator, `!=`.
  notEquals('not equals', '!=', 3),

  /// The greater-than operator, `>`.
  greaterThan('greater than', '>', 4),

  /// The greater-than-or-equal-to operator, `>=`.
  greaterThanOrEquals('greater than or equals', '>=', 4),

  /// The less-than operator, `<`.
  lessThan('less than', '<', 4),

  /// The less-than-or-equal-to operator, `<=`.
  lessThanOrEquals('less than or equals', '<=', 4),

  /// The addition operator, `+`.
  plus('plus', '+', 5, associative: true),

  /// The subtraction operator, `-`.
  minus('minus', '-', 5),

  /// The multiplication operator, `*`.
  times('times', '*', 6, associative: true),

  /// The division operator, `/`.
  dividedBy('divided by', '/', 6),

  /// The modulo operator, `%`.
  modulo('modulo', '%', 6);

  /// The English name of `this`.
  final String name;

  /// The Sass syntax for `this`.
  final String operator;

  /// The precedence of `this`.
  ///
  /// An operator with higher precedence binds tighter.
  final int precedence;

  /// Whether this operation has the [associative property].
  ///
  /// [associative property]: https://en.wikipedia.org/wiki/Associative_property
  final bool isAssociative;

  const BinaryOperator(this.name, this.operator, this.precedence,
      {bool associative = false})
      : isAssociative = associative;

  String toString() => name;
}
