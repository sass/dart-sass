// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../value.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'unary_operation.dart';

/// A list literal.
///
/// {@category AST}
final class ListExpression(
  Iterable<Expression> contents,

  /// Which separator this list uses.
  final ListSeparator separator,
  @override final FileSpan span, {
  bool brackets = false,
}) extends Expression {
  /// The elements of this list.
  final List<Expression> contents = List.unmodifiableOf(contents);

  /// Whether the list has square brackets or not.
  final bool hasBrackets = brackets;

  @override
  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitListExpression(this);

  @override
  String toString() {
    var buffer = StringBuffer();
    if (hasBrackets) {
      buffer.writeCharCode($lbracket);
    } else if (contents.isEmpty ||
        (contents.length == 1 && separator == .comma)) {
      buffer.writeCharCode($lparen);
    }

    buffer.write(
      contents
          .map(
            (element) => _elementNeedsParens(element)
                ? "($element)"
                : element.toString(),
          )
          .join(separator == .comma ? ", " : " "),
    );

    if (hasBrackets) {
      buffer.writeCharCode($rbracket);
    } else if (contents.isEmpty) {
      buffer.writeCharCode($rparen);
    } else if (contents.length == 1 && separator == .comma) {
      buffer.write(",)");
    }

    return buffer.toString();
  }

  /// Returns whether [expression], contained in `this`, needs parentheses when
  /// printed as Sass source.
  bool _elementNeedsParens(Expression expression) => switch (expression) {
    ListExpression(
      contents: [_, _, ...],
      hasBrackets: false,
      separator: var childSeparator,
    ) =>
      separator == .comma
          ? childSeparator == .comma
          : childSeparator != .undecided,
    UnaryOperationExpression(operator: .plus || .minus) => separator == .space,
    _ => false,
  };
}
