// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/comment.dart';
import '../ast/declaration.dart';
import '../ast/statement.dart';
import '../ast/style_rule.dart';
import '../ast/stylesheet.dart';
import '../ast/variable_declaration.dart';

class StatementVisitor<T> {
  T visit(Statement node) => node.visit(this);

  T visitComment(CommentNode node) => null;
  T visitDeclaration(DeclarationNode node) => null;
  T visitVariableDeclaration(VariableDeclarationNode node) => null;

  T visitStyleRule(StyleRuleNode node) {
    for (var child in node.children) {
      child.visit(this);
    }
    return null;
  }

  T visitStylesheet(StylesheetNode node) {
    for (var child in node.children) {
      child.visit(this);
    }
    return null;
  }
}
