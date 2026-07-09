// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/css.dart';
import 'interface/css.dart';

/// A visitor that visits each statements in a CSS AST and returns `true` if all
/// of the individual methods return `true`.
///
/// Each method returns `false` by default.
@internal
mixin EveryCssVisitor implements CssVisitor<bool> {
  @override
  bool visitCssAtRule(CssAtRule node) =>
      node.children.every((child) => child.accept(this));

  @override
  bool visitCssComment(CssComment node) => false;

  @override
  bool visitCssDeclaration(CssDeclaration node) => false;

  @override
  bool visitCssImport(CssImport node) => false;

  @override
  bool visitCssKeyframeBlock(CssKeyframeBlock node) =>
      node.children.every((child) => child.accept(this));

  @override
  bool visitCssMediaRule(CssMediaRule node) =>
      node.children.every((child) => child.accept(this));

  @override
  bool visitCssStyleRule(CssStyleRule node) =>
      node.children.every((child) => child.accept(this));

  @override
  bool visitCssStylesheet(CssStylesheet node) =>
      node.children.every((child) => child.accept(this));

  @override
  bool visitCssSupportsRule(CssSupportsRule node) =>
      node.children.every((child) => child.accept(this));
}
