// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../interface/reference.dart';
import '../interpolation.dart';

/// A function invocation.
///
/// This may be a plain CSS function or a Sass function.
///
/// {@category AST}
@sealed
class FunctionExpression
    implements Expression, CallableInvocation, SassReference {
  /// The namespace of the function being invoked, or `null` if it's invoked
  /// without a namespace.
  final String? namespace;

  /// The name of the function being invoked.
  ///
  /// If [namespace] is non-`null`, underscores are converted to hyphens in this name.
  /// If [namespace] is `null`, this could be a plain CSS function call, so underscores are kept unchanged.
  ///
  /// If this is interpolated, the function will be interpreted as plain CSS,
  /// even if it has the same name as a Sass function.
  final Interpolation interpolatedName;
  String? get name => namespace == null
      ? interpolatedName.asPlain?.replaceAll('_', '-')
      : interpolatedName.asPlain;

  /// The arguments to pass to the function.
  final ArgumentInvocation arguments;

  final FileSpan span;

  FileSpan get nameSpan => interpolatedName.span;

  FileSpan get namespaceSpan => namespace == null
      ? span.start.pointSpan()
      : span.subspan(0, namespace!.length);

  FunctionExpression(this.interpolatedName, this.arguments, this.span,
      {this.namespace});

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitFunctionExpression(this);

  String toString() {
    var buffer = StringBuffer();
    if (namespace != null) buffer.write("$namespace.");
    buffer.write("$interpolatedName$arguments");
    return buffer.toString();
  }
}
