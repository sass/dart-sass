// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../value/list.dart';
import '../../../visitor/sass/expression.dart';
import '../expression.dart';

class ListExpression implements Expression {
  final List<Expression> contents;

  final ListSeparator separator;

  final bool isBracketed;

  final FileSpan span;

  ListExpression(Iterable<Expression> contents, ListSeparator separator,
          {bool bracketed, FileSpan span})
      : this._(new List.unmodifiable(contents), separator, bracketed, span);

  ListExpression._(List<Expression> contents, this.separator, this.isBracketed,
      FileSpan span)
      : contents = contents,
        span = span ?? spanForList(contents);

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitListExpression(this);

  // TODO: parenthesize nested lists if necessary
  String toString() {
    var buffer = new StringBuffer();
    if (isBracketed) buffer.writeCharCode($lbracket);
    buffer.write(contents.join(separator == ListSeparator.comma ? ", " : " "));
    if (isBracketed) buffer.writeCharCode($rbracket);
    return buffer.toString();
  }
}
