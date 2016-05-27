// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass/expression.dart';
import 'ast/sass/node.dart';
import 'ast/sass/statement.dart';
import 'visitor/expression.dart';
import 'visitor/statement.dart';

class AstVisitor<T> extends ExpressionVisitor<T>
    implements StatementVisitor<T> {
  T visit(SassNode node) {
    if (node is Statement) return node.accept(this);
    if (node is Expression) return node.accept(this);
    throw new ArgumentError("Unknown node type $node.");
  }

  T visitComment(CommentNode node) => null;

  T visitDeclaration(DeclarationNode node) {
    visitInterpolationExpression(node.name);
    node.value.accept(this);
    return null;
  }

  T visitStyleRule(StyleRuleNode node) {
    visitInterpolationExpression(node.selector);
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitStylesheet(StylesheetNode node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitVariableDeclaration(VariableDeclarationNode node) {
    node.expression.accept(this);
    return null;
  }
}
