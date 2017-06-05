// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

/// A style rule.
///
/// This applies style declarations to elements that match a given selector.
class StyleRule implements Statement {
  /// The selector to which the declaration will be applied.
  ///
  /// This is only parsed after the interpolation has been resolved.
  final Interpolation selector;

  /// The declarations associated with the selector.
  final List<Statement> children;

  final FileSpan span;

  StyleRule(this.selector, Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitStyleRule(this);

  String toString() => "$selector {${children.join(" ")}}";
}
