// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'argument_declaration.dart';
import 'statement.dart';

/// An abstract class for callables (functions or mixins) that are declared in
/// user code.
abstract class CallableDeclaration implements Statement {
  /// The name of this callable.
  final String name;

  /// The declared arguments this callable accepts.
  final ArgumentDeclaration arguments;

  /// The child statements that are executed when this callable is invoked.
  final List<Statement> children;

  final FileSpan span;

  CallableDeclaration(
      this.name, this.arguments, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);
}
