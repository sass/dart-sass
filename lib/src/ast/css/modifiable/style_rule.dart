// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../../selector.dart';
import '../style_rule.dart';
import 'node.dart';
import 'value.dart';

/// A modifiable version of [CssStyleRule] for use in the evaluation step.
class ModifiableCssStyleRule extends ModifiableCssParentNode
    implements CssStyleRule {
  final ModifiableCssValue<SelectorList> selector;
  final SelectorList originalSelector;
  final FileSpan span;

  /// Creates a new [ModifiableCssStyleRule].
  ///
  /// If [originalSelector] isn't passed, it defaults to [selector.value].
  ModifiableCssStyleRule(ModifiableCssValue<SelectorList> selector, this.span,
      {SelectorList originalSelector})
      : selector = selector,
        originalSelector = originalSelector ?? selector.value;

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssStyleRule(this);

  ModifiableCssStyleRule copyWithoutChildren() =>
      ModifiableCssStyleRule(selector, span,
          originalSelector: originalSelector);
}
