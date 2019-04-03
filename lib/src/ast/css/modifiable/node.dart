// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../../../visitor/interface/modifiable_css.dart';
import '../at_rule.dart';
import '../node.dart';
import '../style_rule.dart';

/// A modifiable version of [CssNode].
///
/// Almost all CSS nodes are the modifiable classes under the covers. However,
/// modification should only be done within the evaluation step, so the
/// unmodifiable types are used elsewhere to enfore that constraint.
abstract class ModifiableCssNode extends CssNode {
  /// The node that contains this, or `null` for the root [CssStylesheet] node.
  ModifiableCssParentNode get parent => _parent;
  ModifiableCssParentNode _parent;

  /// The index of [this] in `parent.children`.
  ///
  /// This makes [remove] more efficient.
  int _indexInParent;

  var isGroupEnd = false;

  /// Whether this node has a visible sibling after it.
  bool get hasFollowingSibling {
    if (_parent == null) return false;
    var siblings = _parent.children;
    for (var i = _indexInParent + 1; i < siblings.length; i++) {
      var sibling = siblings[i];
      if (!_isInvisible(sibling)) return true;
    }
    return false;
  }

  /// Returns whether [node] is invisible for the purposes of
  /// [hasFollowingSibling].
  ///
  /// This can return a false negative for a comment node in compressed mode,
  /// since the AST doesn't know the output style, but that's an extremely
  /// narrow edge case so we don't worry about it.
  bool _isInvisible(CssNode node) {
    if (node is CssParentNode) {
      // An unknown at-rule is never invisible. Because we don't know the
      // semantics of unknown rules, we can't guarantee that (for example)
      // `@foo {}` isn't meaningful.
      if (node is CssAtRule) return false;

      if (node is CssStyleRule && node.selector.value.isInvisible) return true;
      return node.children.every(_isInvisible);
    } else {
      return false;
    }
  }

  T accept<T>(ModifiableCssVisitor<T> visitor);

  /// Removes [this] from [parent]'s child list.
  ///
  /// Throws a [StateError] if [parent] is `null`.
  void remove() {
    if (_parent == null) {
      throw StateError("Can't remove a node without a parent.");
    }

    _parent._children.removeAt(_indexInParent);
    for (var i = _indexInParent; i < _parent._children.length; i++) {
      _parent._children[i]._indexInParent--;
    }
    _parent = null;
  }
}

/// A modifiable version of [CssParentNode] for use in the evaluation step.
abstract class ModifiableCssParentNode extends ModifiableCssNode
    implements CssParentNode {
  final List<ModifiableCssNode> children;
  final List<ModifiableCssNode> _children;
  bool get isChildless => false;

  ModifiableCssParentNode() : this._([]);

  /// A dummy constructor so that [_children] can be passed to the constructor
  /// for [this.children].
  ModifiableCssParentNode._(List<ModifiableCssNode> children)
      : _children = children,
        children = UnmodifiableListView(children);

  /// Returns a copy of [this] with an empty [children] list.
  ///
  /// This is *not* a deep copy. If other parts of this node are modifiable,
  /// they are shared between the new and old nodes.
  ModifiableCssParentNode copyWithoutChildren();

  /// Adds [child] as a child of this statement.
  void addChild(ModifiableCssNode child) {
    child._parent = this;
    child._indexInParent = _children.length;
    _children.add(child);
  }
}
