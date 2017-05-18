// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../interpolation.dart';
import '../statement.dart';

/// A declaration (that is, a `name: value` pair).
class Declaration implements Statement {
  /// The name of this declaration.
  final Interpolation name;

  /// The value of this declaration.
  final Expression value;

  /// The children of this declaration.
  ///
  /// This is `null` if the declaration has no children.
  final List<Statement> children;

  final FileSpan span;

  Declaration(this.name, this.span, {this.value, Iterable<Statement> children})
      : children = children == null ? null : new List.unmodifiable(children);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitDeclaration(this);

  String toString() => "$name: $value;";
}
