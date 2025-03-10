// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/css.dart';
import '../ast/css/modifiable.dart';
import '../ast/selector.dart';
import '../extend/extension_store.dart';
import '../util/box.dart';
import 'interface/css.dart';

/// Returns deep copies of both [stylesheet] and [extender].
///
/// The [extender] must be associated with [stylesheet].
(ModifiableCssStylesheet, ExtensionStore) cloneCssStylesheet(
  CssStylesheet stylesheet,
  ExtensionStore extensionStore,
) {
  var (newExtensionStore, oldToNewSelectors) = extensionStore.clone();

  return (
    _CloneCssVisitor(oldToNewSelectors).visitCssStylesheet(stylesheet),
    newExtensionStore,
  );
}

/// A visitor that creates a deep (and mutable) copy of a [CssStylesheet].
final class _CloneCssVisitor implements CssVisitor<ModifiableCssNode> {
  /// A map from selectors in the original stylesheet to selectors generated for
  /// the new stylesheet using [ExtensionStore.clone].
  final Map<SelectorList, Box<SelectorList>> _oldToNewSelectors;

  _CloneCssVisitor(this._oldToNewSelectors);

  ModifiableCssAtRule visitCssAtRule(CssAtRule node) {
    var rule = ModifiableCssAtRule(
      node.name,
      node.span,
      childless: node.isChildless,
      value: node.value,
    );
    return node.isChildless ? rule : _visitChildren(rule, node);
  }

  ModifiableCssComment visitCssComment(CssComment node) =>
      ModifiableCssComment(node.text, node.span);

  ModifiableCssDeclaration visitCssDeclaration(CssDeclaration node) =>
      ModifiableCssDeclaration(
        node.name,
        node.value,
        node.span,
        parsedAsCustomProperty: node.parsedAsCustomProperty,
        valueSpanForMap: node.valueSpanForMap,
      );

  ModifiableCssImport visitCssImport(CssImport node) =>
      ModifiableCssImport(node.url, node.span, modifiers: node.modifiers);

  ModifiableCssKeyframeBlock visitCssKeyframeBlock(CssKeyframeBlock node) =>
      _visitChildren(
        ModifiableCssKeyframeBlock(node.selector, node.span),
        node,
      );

  ModifiableCssMediaRule visitCssMediaRule(CssMediaRule node) =>
      _visitChildren(ModifiableCssMediaRule(node.queries, node.span), node);

  ModifiableCssStyleRule visitCssStyleRule(CssStyleRule node) {
    if (_oldToNewSelectors[node.selector] case var newSelector?) {
      return _visitChildren(
        ModifiableCssStyleRule(
          newSelector,
          node.span,
          originalSelector: node.originalSelector,
        ),
        node,
      );
    } else {
      throw StateError(
        "The ExtensionStore and CssStylesheet passed to cloneCssStylesheet() "
        "must come from the same compilation.",
      );
    }
  }

  ModifiableCssStylesheet visitCssStylesheet(CssStylesheet node) =>
      _visitChildren(ModifiableCssStylesheet(node.span), node);

  ModifiableCssSupportsRule visitCssSupportsRule(CssSupportsRule node) =>
      _visitChildren(
        ModifiableCssSupportsRule(node.condition, node.span),
        node,
      );

  /// Visits [oldParent]'s children and adds their cloned values as children of
  /// [newParent], then returns [newParent].
  T _visitChildren<T extends ModifiableCssParentNode>(
    T newParent,
    CssParentNode oldParent,
  ) {
    for (var child in oldParent.children) {
      var newChild = child.accept(this);
      newChild.isGroupEnd = child.isGroupEnd;
      newParent.addChild(newChild);
    }
    return newParent;
  }
}
