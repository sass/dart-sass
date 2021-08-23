// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../reference.dart';

/// A function invocation.
///
/// This may be a plain CSS function or a Sass function, but may not include
/// interpolation.
///
/// {@category AST}
@sealed
class FunctionExpression
    implements Expression, CallableInvocation, SassReference {
  /// The namespace of the function being invoked, or `null` if it's invoked
  /// without a namespace.
  final String? namespace;

  /// The name of the function being invoked, with underscores left as-is.
  final String originalName;

  /// The name of the function being invoked, with underscores converted to
  /// hyphens.
  ///
  /// If this function is a plain CSS function, use [originalName] instead.
  final String name;

  /// The arguments to pass to the function.
  final ArgumentInvocation arguments;

  final FileSpan span;

  FileSpan get nameSpan {
    if (namespace == null) return span.initialIdentifier();
    return span.withoutInitialIdentifier().subspan(1).initialIdentifier();
  }

  FileSpan? get namespaceSpan =>
      namespace == null ? null : span.initialIdentifier();

  FunctionExpression(this.originalName, this.arguments, this.span,
      {this.namespace})
      : name = originalName.replaceAll('_', '-');

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitFunctionExpression(this);

  String toString() {
    var buffer = StringBuffer();
    if (namespace != null) buffer.write("$namespace.");
    buffer.write("$originalName$arguments");
    return buffer.toString();
  }
}
