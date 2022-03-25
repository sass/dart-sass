// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../util/span.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../reference.dart';

/// A Sass variable.
///
/// {@category AST}
@sealed
class VariableExpression implements Expression, SassReference {
  /// The namespace of the variable being referenced, or `null` if it's
  /// referenced without a namespace.
  final String? namespace;

  /// The name of this variable, with underscores converted to hyphens.
  final String name;

  final FileSpan span;

  FileSpan get nameSpan {
    if (namespace == null) return span;
    return span.withoutNamespace();
  }

  FileSpan? get namespaceSpan =>
      namespace == null ? null : span.initialIdentifier();

  VariableExpression(this.name, this.span, {this.namespace});

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitVariableExpression(this);

  String toString() => namespace == null ? '\$$name' : '$namespace.\$$name';
}
