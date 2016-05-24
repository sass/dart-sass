// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/node.dart';
import 'ast/comment.dart';
import 'ast/declaration.dart';
import 'ast/expression.dart';
import 'ast/expression/identifier.dart';
import 'ast/expression/interpolation.dart';
import 'ast/expression/list.dart';
import 'ast/expression/string.dart';
import 'ast/style_rule.dart';
import 'ast/stylesheet.dart';
import 'ast/variable_declaration.dart';

class AstVisitor<T> {
  T visit(AstNode node) => node.visit(this);

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

  T visitIdentifierExpression(IdentifierExpression node) {
    visitInterpolationExpression(node.text);
    return null;
  }

  T visitInterpolationExpression(InterpolationExpression node) {
    for (var value in node.contents) {
      if (value is Expression) value.visit(this);
    }
    return null;
  }

  T visitListExpression(ListExpression node) {
    for (var expression in node.contents) {
      expression.visit(this);
    }
    return null;
  }

  T visitStringExpression(StringExpression node) {
    visitInterpolationExpression(node.text);
    return null;
  }
}
