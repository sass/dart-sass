// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:tuple/tuple.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A map literal.
class MapExpression implements Expression {
  /// The pairs in this map.
  ///
  /// This is a list of pairs rather than a map because a map may have two keys
  /// with the same expression (e.g. `(unique-id(): 1, unique-id(): 2)`).
  final List<Tuple2<Expression, Expression>> pairs;

  final FileSpan span;

  MapExpression(Iterable<Tuple2<Expression/*!*/, Expression/*!*/>> pairs, this.span)
      : pairs = List.unmodifiable(pairs);

  T accept<T>(ExpressionVisitor<T> visitor) => visitor.visitMapExpression(this);

  String toString() =>
      '(${pairs.map((pair) => '${pair.item1}: ${pair.item2}').join(', ')})';
}
