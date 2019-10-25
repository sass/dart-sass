// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/css/modifiable.dart';
import '../ast/selector.dart';
import '../extend/extender.dart';
import 'interface/css.dart';

/// Returns deep copies of both [stylesheet] and [extender].
///
/// The [extender] must be associated with [stylesheet].
Tuple2<ModifiableCssStylesheet, Extender> cloneCssStylesheet(
    CssStylesheet stylesheet, Extender extender) {
  var result = extender.clone();
  var newExtender = result.item1;
  var oldToNewSelectors = result.item2;

  return Tuple2(
      _CloneCssVisitor(oldToNewSelectors).visitCssStylesheet(stylesheet),
      newExtender);
}

/// A visitor that creates a deep (and mutable) copy of a [CssStylesheet].
class _CloneCssVisitor implements CssVisitor<ModifiableCssNode> {
  /// A map from selectors in the original stylesheet to selectors generated for
  /// the new stylesheet using [Extender.clone].
  final Map<CssValue<SelectorList>, ModifiableCssValue<SelectorList>>
      _oldToNewSelectors;

  _CloneCssVisitor(this._oldToNewSelectors);

  ModifiableCssAtRule visitCssAtRule(CssAtRule node) {
    var rule = ModifiableCssAtRule(node.name, node.span,
        childless: node.isChildless, value: node.value);
    return node.isChildless ? rule : _visitChildren(rule, node);
  }

  ModifiableCssComment visitCssComment(CssComment node) =>
      ModifiableCssComment(node.text, node.span);

  ModifiableCssDeclaration visitCssDeclaration(CssDeclaration node) =>
      ModifiableCssDeclaration(node.name, node.value, node.span,
          valueSpanForMap: node.valueSpanForMap);

  ModifiableCssImport visitCssImport(CssImport node) =>
      ModifiableCssImport(node.url, node.span,
          supports: node.supports, media: node.media);

  ModifiableCssKeyframeBlock visitCssKeyframeBlock(CssKeyframeBlock node) =>
      _visitChildren(
          ModifiableCssKeyframeBlock(node.selector, node.span), node);

  ModifiableCssMediaRule visitCssMediaRule(CssMediaRule node) =>
      _visitChildren(ModifiableCssMediaRule(node.queries, node.span), node);

  ModifiableCssStyleRule visitCssStyleRule(CssStyleRule node) {
    var newSelector = _oldToNewSelectors[node.selector];
    if (newSelector == null) {
      throw StateError(
          "The Extender and CssStylesheet passed to cloneCssStylesheet() must "
          "come from the same compilation.");
    }

    return _visitChildren(
        ModifiableCssStyleRule(newSelector, node.span,
            originalSelector: node.originalSelector),
        node);
  }

  ModifiableCssStylesheet visitCssStylesheet(CssStylesheet node) =>
      _visitChildren(ModifiableCssStylesheet(node.span), node);

  ModifiableCssSupportsRule visitCssSupportsRule(CssSupportsRule node) =>
      _visitChildren(
          ModifiableCssSupportsRule(node.condition, node.span), node);

  /// Visits [oldParent]'s children and adds their cloned values as children of
  /// [newParent], then returns [newParent].
  T _visitChildren<T extends ModifiableCssParentNode>(
      T newParent, CssParentNode oldParent) {
    for (var child in oldParent.children) {
      var newChild = child.accept(this);
      newChild.isGroupEnd = child.isGroupEnd;
      newParent.addChild(newChild);
    }
    return newParent;
  }
}
