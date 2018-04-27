// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../statement.dart';
import 'parent.dart';

/// A mixin invocation.
class IncludeRule extends ParentStatement implements CallableInvocation {
  /// The name of the mixin being invoked.
  final String name;

  /// The arguments to pass to the mixin.
  final ArgumentInvocation arguments;

  final FileSpan span;

  IncludeRule(this.name, this.arguments, this.span,
      {Iterable<Statement> children})
      : super(children == null ? null : new List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIncludeRule(this);

  String toString() =>
      "@include $name($arguments)" +
      (children == null ? ";" : " {${children.join(' ')}}");
}
