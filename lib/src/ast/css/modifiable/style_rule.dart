// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../util/box.dart';
import '../../../visitor/interface/modifiable_css.dart';
import '../../selector.dart';
import '../style_rule.dart';
import 'node.dart';

/// A modifiable version of [CssStyleRule] for use in the evaluation step.
final class ModifiableCssStyleRule extends ModifiableCssParentNode
    implements CssStyleRule {
  SelectorList get selector => _selector.value;

  /// A reference to the modifiable selector list provided by the extension
  /// store, which may update it over time as new extensions are applied.
  final Box<SelectorList> _selector;

  final SelectorList originalSelector;
  final FileSpan span;
  final bool fromPlainCss;

  /// Creates a new [ModifiableCssStyleRule].
  ///
  /// If [originalSelector] isn't passed, it defaults to [_selector.value].
  ModifiableCssStyleRule(this._selector, this.span,
      {SelectorList? originalSelector, this.fromPlainCss = false})
      : originalSelector = originalSelector ?? _selector.value;

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssStyleRule(this);

  bool equalsIgnoringChildren(ModifiableCssNode other) =>
      other is ModifiableCssStyleRule && other.selector == selector;

  ModifiableCssStyleRule copyWithoutChildren() =>
      ModifiableCssStyleRule(_selector, span,
          originalSelector: originalSelector);
}
