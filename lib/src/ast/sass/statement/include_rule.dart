// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../statement.dart';
import 'content_block.dart';

/// A mixin invocation.
class IncludeRule implements Statement, CallableInvocation {
  /// The namespace of the mixin being invoked, or `null` if it's invoked
  /// without a namespace.
  final String namespace;

  /// The name of the mixin being invoked, with underscores converted to
  /// hyphens.
  final String name;

  /// The arguments to pass to the mixin.
  final ArgumentInvocation arguments;

  /// The block that will be invoked for [ContentRule]s in the mixin being
  /// invoked, or `null` if this doesn't pass a content block.
  final ContentBlock content;

  final FileSpan span;

  IncludeRule(this.name, this.arguments, this.span,
      {this.namespace, this.content});

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIncludeRule(this);

  String toString() {
    var buffer = StringBuffer("@include ");
    if (namespace != null) buffer.write("$namespace.");
    buffer.write(name);
    if (!arguments.isEmpty) buffer.write("($arguments)");
    buffer.write(content == null ? ";" : " $content");
    return buffer.toString();
  }
}
