// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../statement.dart';

/// A mixin invocation.
class IncludeRule implements Statement, CallableInvocation {
  /// The name of the mixin being invoked.
  final String name;

  /// The arguments to pass to the mixin.
  final ArgumentInvocation arguments;

  /// The content block to pass to the mixin, or `null` if there is no content
  /// block.
  final List<Statement> children;

  final FileSpan span;

  IncludeRule(this.name, this.arguments, this.span,
      {Iterable<Statement> children})
      : children = children == null ? null : new List.unmodifiable(children);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIncludeRule(this);

  String toString() =>
      "@include $name($arguments)" +
      (children == null ? ";" : " {${children.join(' ')}}");
}
