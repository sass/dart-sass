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

  final children = new LinkedList<LinkedListValue<MutableNode<T, T>>>();

  MutableNode(this._node) {
    _checkNode();
  }

  void _checkNode() {
    if (node is! Parent) return;
    var parent = node as Parent;
    if (parent.children == null) return;
    if (parent.children.isNotEmpty) return;

    throw new StateError("A mutable node can't have immutable children.");
  }

  N build() {
    if (children.isEmpty) return node;
    if (node is Parent<T, N>) {
      return (node as Parent<T, N>)
          .withChildren(children.map((entry) => entry.value.build()));
    }

    throw new StateError("Non-Parent $node may not have children.");
  }
}
