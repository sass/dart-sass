// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// A `@media` rule.
class MediaRule extends ParentStatement {
  /// The query that determines on which platforms the styles will be in effect.
  ///
  /// This is only parsed after the interpolation has been resolved.
  final Interpolation query;

  final FileSpan span;

  MediaRule(this.query, Iterable<Statement> children, this.span)
      : super(new List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitMediaRule(this);

  String toString() => "@media $query {${children.join(" ")}}";
}
