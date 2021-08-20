// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../interface/reference.dart';

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

  FileSpan get nameSpan =>
      namespace == null ? span : span.subspan(namespace!.length + 1);

  FileSpan get namespaceSpan => namespace == null
      ? span.start.pointSpan()
      : span.subspan(0, namespace!.length);

  VariableExpression(this.name, this.span, {this.namespace});

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitVariableExpression(this);

  String toString() => namespace == null ? '\$$name' : '$namespace.\$$name';
}
