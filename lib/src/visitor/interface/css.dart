// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/css.dart';
import 'modifiable_css.dart';

/// An interface for [visitors][] that traverse CSS statements.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
abstract class CssVisitor<T> implements ModifiableCssVisitor<T> {
  T visitCssAtRule(CssAtRule node);
  T visitCssComment(CssComment node);
  T visitCssDeclaration(CssDeclaration node);
  T visitCssImport(CssImport node);
  T visitCssKeyframeBlock(CssKeyframeBlock node);
  T visitCssMediaRule(CssMediaRule node);
  T visitCssStyleRule(CssStyleRule node);
  T visitCssStylesheet(CssStylesheet node);
  T visitCssSupportsRule(CssSupportsRule node);
}
