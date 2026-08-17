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
final class ModifiableCssStyleRule(
  /// A reference to the modifiable selector list provided by the extension
  /// store, which may update it over time as new extensions are applied.
  final Box<SelectorList> _selector,
  @override final FileSpan span, {
  SelectorList? originalSelector,
  @override final bool fromPlainCss = false,
}) extends ModifiableCssParentNode implements CssStyleRule {
  @override
  SelectorList get selector => _selector.value;

  @override
  final SelectorList originalSelector = originalSelector ?? _selector.value;

  /// Creates a new [ModifiableCssStyleRule].
  ///
  /// If [originalSelector] isn't passed, it defaults to [_selector.value].
  this;

  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssStyleRule(this);

  @override
  bool equalsIgnoringChildren(ModifiableCssNode other) =>
      other is ModifiableCssStyleRule && other.selector == selector;

  @override
  ModifiableCssStyleRule copyWithoutChildren() => ModifiableCssStyleRule(
    _selector,
    span,
    originalSelector: originalSelector,
  );
}
