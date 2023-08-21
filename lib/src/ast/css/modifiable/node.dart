// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../../../visitor/interface/modifiable_css.dart';
import '../node.dart';

/// A modifiable version of [CssNode].
///
/// Almost all CSS nodes are the modifiable classes under the covers. However,
/// modification should only be done within the evaluation step, so the
/// unmodifiable types are used elsewhere to enforce that constraint.
abstract base class ModifiableCssNode extends CssNode {
  /// The node that contains this, or `null` for the root [CssStylesheet] node.
  ModifiableCssParentNode? get parent => _parent;
  ModifiableCssParentNode? _parent;

  /// The index of [this] in `parent.children`.
  ///
  /// This makes [remove] more efficient.
  int? _indexInParent;

  var isGroupEnd = false;

  /// Whether this node has a visible sibling after it.
  bool get hasFollowingSibling =>
      _parent?.children
          .skip(_indexInParent! + 1)
          .any((sibling) => !sibling.isInvisible) ??
      false;

  T accept<T>(ModifiableCssVisitor<T> visitor);

  /// Removes [this] from [parent]'s child list.
  ///
  /// Throws a [StateError] if [parent] is `null`.
  void remove() {
    var parent = _parent;
    if (parent == null) {
      throw StateError("Can't remove a node without a parent.");
    }

    parent._children.removeAt(_indexInParent!);
    for (var child in parent._children.skip(_indexInParent!)) {
      child._indexInParent = child._indexInParent! - 1;
    }
    _parent = null;
  }
}

/// A modifiable version of [CssParentNode] for use in the evaluation step.
abstract base class ModifiableCssParentNode extends ModifiableCssNode
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

  /// Returns whether [this] is equal to [other], ignoring their child nodes.
  bool equalsIgnoringChildren(ModifiableCssNode other);

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

  /// Destructively removes all elements from [children].
  void clearChildren() {
    for (var child in _children) {
      child._parent = null;
      child._indexInParent = null;
    }
    _children.clear();
  }
}
