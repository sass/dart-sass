// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/css/modifiable.dart';

/// An interface for [visitors][] that traverse CSS statements.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
abstract class ModifiableCssVisitor<T> {
  T visitCssAtRule(ModifiableCssAtRule node);
  T visitCssComment(ModifiableCssComment node);
  T visitCssDeclaration(ModifiableCssDeclaration node);
  T visitCssImport(ModifiableCssImport node);
  T visitCssKeyframeBlock(ModifiableCssKeyframeBlock node);
  T visitCssMediaRule(ModifiableCssMediaRule node);
  T visitCssStyleRule(ModifiableCssStyleRule node);
  T visitCssStylesheet(ModifiableCssStylesheet node);
  T visitCssSupportsRule(ModifiableCssSupportsRule node);
}
