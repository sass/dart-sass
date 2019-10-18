// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/css/modifiable.dart';
import '../extend/extender.dart';
import 'interface/css.dart';

/// Returns deep copies of both [stylesheet] and [extender].
///
/// The [extender] must be associated with [stylesheet].
Tuple2<ModifiableCssStylesheet, Extender> cloneCssStylesheet(
    CssStylesheet stylesheet, Extender extender) {
  var result = extender.clone();
  var newExtender = result.item1;
  var oldToNewRules = result.item2;

  return Tuple2(_CloneCssVisitor(oldToNewRules).visitCssStylesheet(stylesheet),
      newExtender);
}

/// A visitor that creates a deep (and mutable) copy of a [CssStylesheet].
class _CloneCssVisitor implements CssVisitor<ModifiableCssNode> {
  /// A map from style rules in the original stylesheet to style rules generated
  /// for the new stylesheet using [Extender.clone].
  final Map<CssStyleRule, ModifiableCssStyleRule> _oldToNewRules;

  _CloneCssVisitor(this._oldToNewRules);

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
    var newRule = _oldToNewRules[node];
    if (newRule == null) {
      throw StateError(
          "The Extender and CssStylesheet passed to cloneCssStylesheet() must "
          "come from the same compilation.");
    }

    return _visitChildren(newRule, node);
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
