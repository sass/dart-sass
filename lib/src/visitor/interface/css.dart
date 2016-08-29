// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/css.dart';

abstract class CssVisitor<T> {
  T visitAtRule(CssAtRule node);
  T visitComment(CssComment node);
  T visitDeclaration(CssDeclaration node);
  T visitImport(CssImport node);
  T visitMediaRule(CssMediaRule node);
  T visitStyleRule(CssStyleRule node);
  T visitStylesheet(CssStylesheet node);
}
