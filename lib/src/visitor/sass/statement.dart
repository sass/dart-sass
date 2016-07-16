// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass/statement.dart';

class StatementVisitor<T> {
  T visitComment(Comment node) => null;
  T visitDeclaration(Declaration node) => null;
  T visitExtendRule(ExtendRule node) => null;
  T visitVariableDeclaration(VariableDeclaration node) => null;

  T visitAtRule(AtRule node) {
    if (node.children == null) return null;
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitMediaRule(MediaRule node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitStyleRule(StyleRule node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitStylesheet(Stylesheet node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }
}
