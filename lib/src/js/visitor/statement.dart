// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../ast/sass.dart';
import '../../visitor/interface/statement.dart';

/// A wrapper around a JS object that implements the [StatementVisitor] methods.
class JSStatementVisitor implements StatementVisitor<Object?> {
  final JSStatementVisitorObject _inner;

  JSStatementVisitor(this._inner);

  Object? visitAtRootRule(AtRootRule node) => _inner.visitAtRootRule(node);
  Object? visitAtRule(AtRule node) => _inner.visitAtRule(node);
  Object? visitContentBlock(ContentBlock node) =>
      _inner.visitContentBlock(node);
  Object? visitContentRule(ContentRule node) => _inner.visitContentRule(node);
  Object? visitDebugRule(DebugRule node) => _inner.visitDebugRule(node);
  Object? visitDeclaration(Declaration node) => _inner.visitDeclaration(node);
  Object? visitEachRule(EachRule node) => _inner.visitEachRule(node);
  Object? visitErrorRule(ErrorRule node) => _inner.visitErrorRule(node);
  Object? visitExtendRule(ExtendRule node) => _inner.visitExtendRule(node);
  Object? visitForRule(ForRule node) => _inner.visitForRule(node);
  Object? visitForwardRule(ForwardRule node) => _inner.visitForwardRule(node);
  Object? visitFunctionRule(FunctionRule node) =>
      _inner.visitFunctionRule(node);
  Object? visitIfRule(IfRule node) => _inner.visitIfRule(node);
  Object? visitImportRule(ImportRule node) => _inner.visitImportRule(node);
  Object? visitIncludeRule(IncludeRule node) => _inner.visitIncludeRule(node);
  Object? visitLoudComment(LoudComment node) => _inner.visitLoudComment(node);
  Object? visitMediaRule(MediaRule node) => _inner.visitMediaRule(node);
  Object? visitMixinRule(MixinRule node) => _inner.visitMixinRule(node);
  Object? visitReturnRule(ReturnRule node) => _inner.visitReturnRule(node);
  Object? visitSilentComment(SilentComment node) =>
      _inner.visitSilentComment(node);
  Object? visitStyleRule(StyleRule node) => _inner.visitStyleRule(node);
  Object? visitStylesheet(Stylesheet node) => _inner.visitStylesheet(node);
  Object? visitSupportsRule(SupportsRule node) =>
      _inner.visitSupportsRule(node);
  Object? visitUseRule(UseRule node) => _inner.visitUseRule(node);
  Object? visitVariableDeclaration(VariableDeclaration node) =>
      _inner.visitVariableDeclaration(node);
  Object? visitWarnRule(WarnRule node) => _inner.visitWarnRule(node);
  Object? visitWhileRule(WhileRule node) => _inner.visitWhileRule(node);
}

@JS()
class JSStatementVisitorObject {
  external Object? visitAtRootRule(AtRootRule node);
  external Object? visitAtRule(AtRule node);
  external Object? visitContentBlock(ContentBlock node);
  external Object? visitContentRule(ContentRule node);
  external Object? visitDebugRule(DebugRule node);
  external Object? visitDeclaration(Declaration node);
  external Object? visitEachRule(EachRule node);
  external Object? visitErrorRule(ErrorRule node);
  external Object? visitExtendRule(ExtendRule node);
  external Object? visitForRule(ForRule node);
  external Object? visitForwardRule(ForwardRule node);
  external Object? visitFunctionRule(FunctionRule node);
  external Object? visitIfRule(IfRule node);
  external Object? visitImportRule(ImportRule node);
  external Object? visitIncludeRule(IncludeRule node);
  external Object? visitLoudComment(LoudComment node);
  external Object? visitMediaRule(MediaRule node);
  external Object? visitMixinRule(MixinRule node);
  external Object? visitReturnRule(ReturnRule node);
  external Object? visitSilentComment(SilentComment node);
  external Object? visitStyleRule(StyleRule node);
  external Object? visitStylesheet(Stylesheet node);
  external Object? visitSupportsRule(SupportsRule node);
  external Object? visitUseRule(UseRule node);
  external Object? visitVariableDeclaration(VariableDeclaration node);
  external Object? visitWarnRule(WarnRule node);
  external Object? visitWhileRule(WhileRule node);
}
