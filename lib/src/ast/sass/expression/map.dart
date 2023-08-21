// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A map literal.
///
/// {@category AST}
final class MapExpression implements Expression {
  /// The pairs in this map.
  ///
  /// This is a list of pairs rather than a map because a map may have two keys
  /// with the same expression (e.g. `(unique-id(): 1, unique-id(): 2)`).
  final List<(Expression, Expression)> pairs;

  final FileSpan span;

  MapExpression(Iterable<(Expression, Expression)> pairs, this.span)
      : pairs = List.unmodifiable(pairs);

  T accept<T>(ExpressionVisitor<T> visitor) => visitor.visitMapExpression(this);

  String toString() =>
      '(${[for (var (key, value) in pairs) '$key: $value'].join(', ')})';
}
