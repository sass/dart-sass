// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'node.dart';

abstract class Parent<T extends AstNode, N extends T> extends AstNode {
  List<T> get children;

  N withChildren(Iterable<T> children);
}
