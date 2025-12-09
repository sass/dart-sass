// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolated_selector/list.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// A style rule.
///
/// This applies style declarations to elements that match a given selector.
///
/// {@category AST}
final class StyleRule extends ParentStatement<List<Statement>> {
  /// The selector to which the declaration will be applied.
  ///
  /// This is only parsed after the interpolation has been resolved. This is
  /// null if and only if [parsedSelector] is not null.
  final Interpolation? selector;

  /// Like [selector], but with as much of the selector parsed as possible.
  ///
  /// This isn't used by Sass's internal logic, and is only set when
  /// `parseSelectors: true` is passed to [Stylesheet.parse]. This is null if
  /// and only if [selector] is not null.
  final InterpolatedSelectorList? parsedSelector;

  final FileSpan span;

  /// Constructs a style rule with [selector] set and [parsedSelector] null.
  StyleRule(this.selector, Iterable<Statement> children, this.span)
      : parsedSelector = null,
        super(List.unmodifiable(children));

  /// Constructs a style rule with [parsedSelector] set and [selector].
  StyleRule.withParsedSelector(
      this.parsedSelector, Iterable<Statement> children, this.span)
      : selector = null,
        super(List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitStyleRule(this);

  String toString() => "${selector ?? parsedSelector} {${children.join(" ")}}";
}
