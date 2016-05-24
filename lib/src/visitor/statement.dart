// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass/comment.dart';
import '../ast/sass/declaration.dart';
import '../ast/sass/statement.dart';
import '../ast/sass/style_rule.dart';
import '../ast/sass/stylesheet.dart';
import '../ast/sass/variable_declaration.dart';

class StatementVisitor<T> {
  T visit(Statement node) => node.visit(this);

  T visitComment(Comment node) => null;
  T visitDeclaration(Declaration node) => null;
  T visitVariableDeclaration(VariableDeclaration node) => null;

  T visitStyleRule(StyleRule node) {
    for (var child in node.children) {
      child.visit(this);
    }
    return null;
  }

  T visitStylesheet(Stylesheet node) {
    for (var child in node.children) {
      child.visit(this);
    }
    return null;
  }
}
