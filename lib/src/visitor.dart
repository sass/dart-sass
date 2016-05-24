// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/comment.dart';
import 'ast/declaration.dart';
import 'ast/expression.dart';
import 'ast/node.dart';
import 'ast/statement.dart';
import 'ast/style_rule.dart';
import 'ast/stylesheet.dart';
import 'ast/variable_declaration.dart';
import 'visitor/expression.dart';
import 'visitor/statement.dart';

class AstVisitor<T> extends ExpressionVisitor<T>
    implements StatementVisitor<T> {
  T visit(AstNode node) {
    if (node is Statement) return node.visit(this);
    if (node is Expression) return node.visit(this);
    throw new ArgumentError("Unknown node type $node.");
  }

  T visitComment(CommentNode node) => null;

  T visitDeclaration(DeclarationNode node) {
    visitInterpolationExpression(node.name);
    node.value.visit(this);
    return null;
  }

  T visitStyleRule(StyleRuleNode node) {
    visitInterpolationExpression(node.selector);
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

  T visitVariableDeclaration(VariableDeclarationNode node) {
    node.expression.visit(this);
    return null;
  }
}
