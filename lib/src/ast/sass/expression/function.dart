// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../interpolation.dart';

/// A function invocation.
///
/// This may be a plain CSS function or a Sass function.
class FunctionExpression implements Expression, CallableInvocation {
  /// The namespace of the function being invoked, or `null` if it's invoked
  /// without a namespace.
  final String namespace;

  /// The name of the function being invoked.
  ///
  /// Underscores aren't converted to hyphens in this name *unless* [namespace]
  /// is non-`null`, since otherwise it could be a plain CSS function call.
  ///
  /// If this is interpolated, the function will be interpreted as plain CSS,
  /// even if it has the same name as a Sass function.
  final Interpolation name;

  /// The arguments to pass to the function.
  final ArgumentInvocation arguments;

  final FileSpan span;

  FunctionExpression(this.name, this.arguments, this.span, {this.namespace});

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitFunctionExpression(this);

  String toString() {
    var buffer = StringBuffer();
    if (namespace != null) buffer.write("$namespace.");
    buffer.write("$name$arguments");
    return buffer.toString();
  }
}
