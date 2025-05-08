// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import '../../ast/sass.dart';
import '../../visitor/interface/statement.dart';
import '../hybrid/content_rule.dart';
import '../hybrid/include_rule.dart';
import '../hybrid/loud_comment.dart';

/// A wrapper around a JS object that implements the [StatementVisitor] methods.
class JSStatementVisitor implements StatementVisitor<JSAny?> {
  final JSStatementVisitorObject _inner;

  JSStatementVisitor(this._inner);

  JSAny? visitAtRootRule(AtRootRule node) =>
      _inner.visitAtRootRule(node as JSObject);
  JSAny? visitAtRule(AtRule node) => _inner.visitAtRule(node as JSObject);
  JSAny? visitContentBlock(ContentBlock node) =>
      _inner.visitContentBlock(node as JSObject);
  JSAny? visitContentRule(ContentRule node) =>
      _inner.visitContentRule(node.toJS);
  JSAny? visitDebugRule(DebugRule node) =>
      _inner.visitDebugRule(node as JSObject);
  JSAny? visitDeclaration(Declaration node) =>
      _inner.visitDeclaration(node as JSObject);
  JSAny? visitEachRule(EachRule node) => _inner.visitEachRule(node as JSObject);
  JSAny? visitErrorRule(ErrorRule node) =>
      _inner.visitErrorRule(node as JSObject);
  JSAny? visitExtendRule(ExtendRule node) =>
      _inner.visitExtendRule(node as JSObject);
  JSAny? visitForRule(ForRule node) => _inner.visitForRule(node as JSObject);
  JSAny? visitForwardRule(ForwardRule node) =>
      _inner.visitForwardRule(node as JSObject);
  JSAny? visitFunctionRule(FunctionRule node) =>
      _inner.visitFunctionRule(node as JSObject);
  JSAny? visitIfRule(IfRule node) => _inner.visitIfRule(node as JSObject);
  JSAny? visitImportRule(ImportRule node) =>
      _inner.visitImportRule(node as JSObject);
  JSAny? visitIncludeRule(IncludeRule node) =>
      _inner.visitIncludeRule(node.toJS);
  JSAny? visitLoudComment(LoudComment node) =>
      _inner.visitLoudComment(node.toJS);
  JSAny? visitMediaRule(MediaRule node) =>
      _inner.visitMediaRule(node as JSObject);
  JSAny? visitMixinRule(MixinRule node) =>
      _inner.visitMixinRule(node as JSObject);
  JSAny? visitReturnRule(ReturnRule node) =>
      _inner.visitReturnRule(node as JSObject);
  JSAny? visitSilentComment(SilentComment node) =>
      _inner.visitSilentComment(node as JSObject);
  JSAny? visitStyleRule(StyleRule node) =>
      _inner.visitStyleRule(node as JSObject);
  JSAny? visitStylesheet(Stylesheet node) =>
      _inner.visitStylesheet(node as JSObject);
  JSAny? visitSupportsRule(SupportsRule node) =>
      _inner.visitSupportsRule(node as JSObject);
  JSAny? visitUseRule(UseRule node) => _inner.visitUseRule(node as JSObject);
  JSAny? visitVariableDeclaration(VariableDeclaration node) =>
      _inner.visitVariableDeclaration(node as JSObject);
  JSAny? visitWarnRule(WarnRule node) => _inner.visitWarnRule(node as JSObject);
  JSAny? visitWhileRule(WhileRule node) =>
      _inner.visitWhileRule(node as JSObject);
}

@JS()
class JSStatementVisitorObject {
  external JSAny? visitAtRootRule(JSObject node);
  external JSAny? visitAtRule(JSObject node);
  external JSAny? visitContentBlock(JSObject node);
  external JSAny? visitContentRule(JSContentRule node);
  external JSAny? visitDebugRule(JSObject node);
  external JSAny? visitDeclaration(JSObject node);
  external JSAny? visitEachRule(JSObject node);
  external JSAny? visitErrorRule(JSObject node);
  external JSAny? visitExtendRule(JSObject node);
  external JSAny? visitForRule(JSObject node);
  external JSAny? visitForwardRule(JSObject node);
  external JSAny? visitFunctionRule(JSObject node);
  external JSAny? visitIfRule(JSObject node);
  external JSAny? visitImportRule(JSObject node);
  external JSAny? visitIncludeRule(JSIncludeRule node);
  external JSAny? visitLoudComment(JSLoudComment node);
  external JSAny? visitMediaRule(JSObject node);
  external JSAny? visitMixinRule(JSObject node);
  external JSAny? visitReturnRule(JSObject node);
  external JSAny? visitSilentComment(JSObject node);
  external JSAny? visitStyleRule(JSObject node);
  external JSAny? visitStylesheet(JSObject node);
  external JSAny? visitSupportsRule(JSObject node);
  external JSAny? visitUseRule(JSObject node);
  external JSAny? visitVariableDeclaration(JSObject node);
  external JSAny? visitWarnRule(JSObject node);
  external JSAny? visitWhileRule(JSObject node);
}
