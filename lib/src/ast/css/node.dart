// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../../visitor/interface/css.dart';
import '../../visitor/serialize.dart';
import '../node.dart';

/// A statement in a plain CSS syntax tree.
abstract class CssNode extends AstNode {
  /// The node that contains this, or `null` for the root [CssStylesheet] node.
  CssParentNode get parent => _parent;
  CssParentNode _parent;

  /// The index of [this] in `parent.children`.
  ///
  /// This makes [remove] more efficient.
  int _indexInParent;

  /// If `true`, this node should not be emitted to CSS.
  bool get isInvisible => false;

  /// Whether this was generated from the last node in a nested Sass tree that
  /// got flattened during evaluation.
  var isGroupEnd = false;

  /// Calls the appropriate visit method on [visitor].
  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor);

  /// Removes [this] from [parent]'s child list.
  ///
  /// Throws a [StateError] if [parent] is `null`.
  void remove() {
    if (_parent == null) {
      throw new StateError("Can't remove a node without a parent.");
    }

    _parent._children.removeAt(_indexInParent);
    for (var i = _indexInParent; i < _parent._children.length; i++) {
      _parent._children[i]._indexInParent--;
    }
    _parent = null;
  }

  String toString() => toCss(this, inspect: true);
}

// NOTE: New at-rule implementations should add themselves to [AtRootRule]'s
// exclude logic.
/// A [CssNode] that can have child statements.
abstract class CssParentNode extends CssNode {
  /// The child statements of this node.
  final List<CssNode> children;
  final List<CssNode> _children;

  /// By default, a parent node is invisible if it's empty or if all its
  /// children are invisible.
  bool get isInvisible {
    if (_isInvisible == null) {
      _isInvisible = children.every((child) => child.isInvisible);
    }
    return _isInvisible;
  }

  bool _isInvisible;

  CssParentNode() : this._([]);

  /// A dummy constructor so that [_children] can be passed to the constructor
  /// for [this.children].
  CssParentNode._(List<CssNode> children)
      : _children = children,
        children = new UnmodifiableListView<CssNode>(children);

  /// Returns a copy of [this] with an empty [children] list.
  CssParentNode copyWithoutChildren();

  /// Passes a modifiable view of [children] to [modify].
  ///
  /// This is used to explicitly indicate when modifications are intended so
  /// that [children] can remain unmodifiable by default.
  void modifyChildren(void modify(List<CssNode> children)) {
    modify(_children);
  }

  /// Adds [child] as a child of this statement.
  void addChild(CssNode child) {
    child._parent = this;
    child._indexInParent = _children.length;
    _children.add(child);
  }
}
