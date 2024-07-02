// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';
import 'parent.dart';

/// A `@nest` rule.
///
/// This ensures that the nesting and ordering of its contents match that
/// [specified by CSS].
///
/// [specified by CSS]: https://drafts.csswg.org/css-nesting/#mixing
///
/// {@category AST}
final class NestRule extends ParentStatement<List<Statement>> {
  final FileSpan span;

  NestRule(Iterable<Statement> children, this.span)
      : super(List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitNestRule(this);

  String toString() => "@nest {${children.join(' ')}}";
}
