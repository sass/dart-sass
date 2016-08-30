// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass.dart';

abstract class StatementVisitor<T> {
  T visitAtRule(AtRule node);
  T visitComment(Comment node);
  T visitContent(Content node);
  T visitDeclaration(Declaration node);
  T visitExtendRule(ExtendRule node);
  T visitFunctionDeclaration(FunctionDeclaration node);
  T visitIf(If node);
  T visitImport(Import node);
  T visitInclude(Include node);
  T visitMediaRule(MediaRule node);
  T visitMixinDeclaration(MixinDeclaration node);
  T visitPlainImport(PlainImport node);
  T visitReturn(Return node);
  T visitStyleRule(StyleRule node);
  T visitStylesheet(Stylesheet node);
  T visitSupportsRule(SupportsRule node);
  T visitVariableDeclaration(VariableDeclaration node);
}
