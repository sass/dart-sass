// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/css.dart';
import 'modifiable_css.dart';

/// An interface for [visitors][] that traverse CSS statements.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
abstract interface class CssVisitor<T> implements ModifiableCssVisitor<T> {
  @override
  T visitCssAtRule(CssAtRule node);

  @override
  T visitCssComment(CssComment node);

  @override
  T visitCssDeclaration(CssDeclaration node);

  @override
  T visitCssImport(CssImport node);

  @override
  T visitCssKeyframeBlock(CssKeyframeBlock node);

  @override
  T visitCssMediaRule(CssMediaRule node);

  @override
  T visitCssStyleRule(CssStyleRule node);

  @override
  T visitCssStylesheet(CssStylesheet node);

  @override
  T visitCssSupportsRule(CssSupportsRule node);
}
