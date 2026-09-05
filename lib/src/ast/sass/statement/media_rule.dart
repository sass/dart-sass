// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// A `@media` rule.
///
/// {@category AST}
final class MediaRule(
  /// The query that determines on which platforms the styles will be in effect.
  ///
  /// This is only parsed after the interpolation has been resolved.
  final Interpolation query,
  Iterable<Statement> children,
  @override final FileSpan span,
) extends ParentStatement<List<Statement>> {
  this : super(List.unmodifiableOf(children));

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitMediaRule(this);

  @override
  String toString() => "@media $query {${children.join(" ")}}";
}
