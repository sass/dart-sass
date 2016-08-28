// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../value.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'unary_operator.dart';

class ListExpression implements Expression {
  final List<Expression> contents;

  final ListSeparator separator;

  final bool isBracketed;

  final FileSpan span;

  ListExpression(Iterable<Expression> contents, ListSeparator separator,
      {bool bracketed: false, FileSpan span})
      : this._(new List.unmodifiable(contents), separator, bracketed, span);

  ListExpression._(List<Expression> contents, this.separator, this.isBracketed,
      FileSpan span)
      : contents = contents,
        span = span ?? spanForList(contents);

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitListExpression(this);

  String toString() {
    var buffer = new StringBuffer();
    if (isBracketed) buffer.writeCharCode($lbracket);
    buffer.write(contents
        .map((element) =>
            _elementNeedsParens(element) ? "($element)" : element.toString())
        .join(separator == ListSeparator.comma ? ", " : " "));
    if (isBracketed) buffer.writeCharCode($rbracket);
    return buffer.toString();
  }

  bool _elementNeedsParens(Expression expression) {
    if (expression is ListExpression) {
      if (expression.contents.length < 2) return false;
      if (expression.isBracketed) return false;
      return separator == ListSeparator.comma
          ? separator == ListSeparator.comma
          : separator != ListSeparator.undecided;
    }

    if (separator != ListSeparator.space) return false;

    if (expression is UnaryOperatorExpression) {
      return expression.operator == UnaryOperator.plus ||
          expression.operator == UnaryOperator.minus;
    }

    // TODO: handle binary operations.
    return false;
  }
}
