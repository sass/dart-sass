// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../expression.dart';
import '../../utils.dart';

class ListExpression implements Expression {
  final List<Expression> contents;

  final ListSeparator separator;

  final SourceSpan span;

  ListExpression(Iterable<Expression> contents, ListSeparator separator,
          {SourceSpan span})
      : this._(new List.unmodifiable(contents), separator, span);

  ListExpression._(List<Expression> contents, this.separator, SourceSpan span)
      : contents = contents,
        span = span ?? spanForList(contents);

  // TODO: parenthesize nested lists if necessary
  String toString() => contents.map((value) => value.toString())
      .join(separator == ListSeparator.comma ? ", " : " ");
}

// TODO: move to list value file?
class ListSeparator {
  static const space = const ListSeparator._("space");
  static const comma = const ListSeparator._("comma");

  final String name;

  const ListSeparator._(this.name);

  String toString() => name;
}
