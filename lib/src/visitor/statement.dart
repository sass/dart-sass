// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass/statement.dart';

class StatementVisitor<T> {
  T visit(Statement node) => node.accept(this);

  T visitComment(Comment node) => null;
  T visitDeclaration(Declaration node) => null;
  T visitVariableDeclaration(VariableDeclaration node) => null;

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
