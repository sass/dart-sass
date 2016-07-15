// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'ast/node.dart';
import 'ast/parent.dart';
import 'utils.dart';

class MutableNode<T extends AstNode, N extends T> {
  N get node => _node;

  void set node(N value) {
    _node = value;
    _checkNode();
  }

  N _node;

  final MutableNode<T, T> parent;

  LinkedListValue<MutableNode<T, N>> _linkedListValue;

  Iterable<MutableNode<T, T>> get children =>
      _children.map((value) => value.value);
  final _children = new LinkedList<LinkedListValue<MutableNode<T, T>>>();

  MutableNode.root(this._node) : parent = null {
    _checkNode();
  }

  MutableNode._(this.parent, this._node) {
    _checkNode();
  }

  MutableNode<T, T/*=S*/> add/*<S extends T>*/(T/*=S*/ child) {
    var node = new MutableNode<T, T/*=S*/>._(this, child);
    node._linkedListValue = new LinkedListValue(node);
    _children.add(node._linkedListValue);
    return node;
  }

  void remove() {
    _linkedListValue.unlink();
  }

  void _checkNode() {
    if (node is! Parent) return;
    var parent = node as Parent;
    if (parent.children == null) return;
    if (parent.children.isEmpty) return;

    throw new StateError("A mutable node can't have immutable children.");
  }

  N build() {
    if (children.isEmpty) return node;
    if (node is Parent<T, N>) {
      return (node as Parent<T, N>)
          .withChildren(children.map((entry) => entry.build()));
    }

    throw new StateError("Non-Parent $node may not have children.");
  }
}
