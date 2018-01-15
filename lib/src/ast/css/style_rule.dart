// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import '../selector.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS style rule.
///
/// This applies style declarations to elements that match a given selector.
/// Note that this isn't *strictly* plain CSS, since [selector] may still
/// contain placeholder selectors.
class CssStyleRule extends CssParentNode {
  /// The selector for this rule.
  final CssValue<SelectorList> selector;

  /// The selector for this rule, before any extensions are applied.
  final SelectorList originalSelector;

  final FileSpan span;

  /// Creates a new [CssStyleRule].
  ///
  /// If [originalSelector] isn't passed, it defaults to [selector.value].
  CssStyleRule(CssValue<SelectorList> selector, this.span,
      {SelectorList originalSelector})
      : selector = selector,
        originalSelector = originalSelector ?? selector.value;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitStyleRule(this);

  CssStyleRule copyWithoutChildren() =>
      new CssStyleRule(selector, span, originalSelector: originalSelector);
}
