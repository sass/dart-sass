// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';

/// A Sass variable.
class VariableExpression implements Expression {
  /// The namespace of the variable being referenced, or `null` if it's
  /// referenced without a namespace.
  final String namespace;

  /// The name of this variable, with underscores converted to hyphens.
  final String name;

  final FileSpan span;

  VariableExpression(this.name, this.span, {this.namespace});

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitVariableExpression(this);

  String toString() {
    var buffer = StringBuffer("\$");
    if (namespace != null) buffer.write("$namespace.");
    buffer.write(name);
    return buffer.toString();
  }
}
