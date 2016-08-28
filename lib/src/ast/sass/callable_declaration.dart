// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'argument_declaration.dart';
import 'statement.dart';

abstract class CallableDeclaration implements Statement {
  final String name;

  final ArgumentDeclaration arguments;

  final List<Statement> children;

  final FileSpan span;

  CallableDeclaration(
      this.name, this.arguments, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);
}
