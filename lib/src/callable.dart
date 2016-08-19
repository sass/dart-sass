// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'ast/sass/statement.dart';
import 'environment.dart';

class Callable {
  final String name;

  final ArgumentDeclaration arguments;

  final List<Statement> children;

  final Environment environment;

  final FileSpan span;

  Callable(this.name, this.arguments, Iterable<Statement> children,
      this.environment, {this.span})
      : children = new List.unmodifiable(children);
}
