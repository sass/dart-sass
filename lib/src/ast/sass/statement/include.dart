// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../statement.dart';

class Include implements Statement, CallableInvocation {
  final String name;

  final ArgumentInvocation arguments;

  final List<Statement> children;

  final FileSpan span;

  Include(this.name, this.arguments, {Iterable<Statement> children,
      this.span})
      : children = children == null ? null : new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitInclude(this);

  String toString() => "@include $name($arguments)" +
      (children == null ? ";" : " {${children.join(' ')}}");
}
