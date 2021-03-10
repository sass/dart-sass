// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../../../value.dart';
import '../expression.dart';

/// An expression that directly embeds a [Value].
///
/// This is never constructed by the parser. It's only used when ASTs are
/// constructed dynamically, as for the `call()` function.
class ValueExpression implements Expression {
  /// The embedded value.
  final Value/*!*/ value;

  final FileSpan span;

  ValueExpression(this.value, [this.span]);

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitValueExpression(this);

  String toString() => value.toString();
}
