// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../value.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'unary_operation.dart';

/// A list literal.
class ListExpression implements Expression {
  /// The elements of this list.
  final List<Expression> contents;

  /// Which separator this list uses.
  final ListSeparator separator;

  /// Whether the list has square brackets or not.
  final bool hasBrackets;

  final FileSpan span;

  ListExpression(Iterable<Expression/*!*/> contents, ListSeparator separator,
      {bool brackets = false, FileSpan span})
      : this._(List.unmodifiable(contents), separator, brackets, span);

  ListExpression._(List<Expression> contents, this.separator, this.hasBrackets,
      FileSpan span)
      : contents = contents,
        span = span ?? spanForList(contents);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitListExpression(this);

  String toString() {
    var buffer = StringBuffer();
    if (hasBrackets) buffer.writeCharCode($lbracket);
    buffer.write(contents
        .map((element) =>
            _elementNeedsParens(element) ? "($element)" : element.toString())
        .join(separator == ListSeparator.comma ? ", " : " "));
    if (hasBrackets) buffer.writeCharCode($rbracket);
    return buffer.toString();
  }

  /// Returns whether [expression], contained in [this], needs parentheses when
  /// printed as Sass source.
  bool _elementNeedsParens(Expression expression) {
    if (expression is ListExpression) {
      if (expression.contents.length < 2) return false;
      if (expression.hasBrackets) return false;
      return separator == ListSeparator.comma
          ? separator == ListSeparator.comma
          : separator != ListSeparator.undecided;
    }

    if (separator != ListSeparator.space) return false;

    if (expression is UnaryOperationExpression) {
      return expression.operator == UnaryOperator.plus ||
          expression.operator == UnaryOperator.minus;
    }

    return false;
  }
}
