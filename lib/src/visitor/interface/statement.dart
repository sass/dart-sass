// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass.dart';

abstract class StatementVisitor<T> {
  T visitComment(Comment node) => null;
  T visitContent(Content node) => null;
  T visitExtendRule(ExtendRule node) => null;
  T visitImport(Import node) => null;
  T visitReturn(Return node) => null;
  T visitVariableDeclaration(VariableDeclaration node) => null;

  T visitDeclaration(Declaration node) {
    if (node.children == null) return null;
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitAtRule(AtRule node) {
    if (node.children == null) return null;
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitFunctionDeclaration(FunctionDeclaration node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitIf(If node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitInclude(Include node) {
    if (node.children == null) return null;
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  T visitMixinDeclaration(MixinDeclaration node) {
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
