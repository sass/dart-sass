// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

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
      _inner.visitAtRootRule(node.toUnsafeWrapper);
  JSAny? visitAtRule(AtRule node) => _inner.visitAtRule(node.toUnsafeWrapper);
  JSAny? visitContentBlock(ContentBlock node) =>
      _inner.visitContentBlock(node.toUnsafeWrapper);
  JSAny? visitContentRule(ContentRule node) =>
      _inner.visitContentRule(node.toJS);
  JSAny? visitDebugRule(DebugRule node) =>
      _inner.visitDebugRule(node.toUnsafeWrapper);
  JSAny? visitDeclaration(Declaration node) =>
      _inner.visitDeclaration(node.toUnsafeWrapper);
  JSAny? visitEachRule(EachRule node) =>
      _inner.visitEachRule(node.toUnsafeWrapper);
  JSAny? visitErrorRule(ErrorRule node) =>
      _inner.visitErrorRule(node.toUnsafeWrapper);
  JSAny? visitExtendRule(ExtendRule node) =>
      _inner.visitExtendRule(node.toUnsafeWrapper);
  JSAny? visitForRule(ForRule node) =>
      _inner.visitForRule(node.toUnsafeWrapper);
  JSAny? visitForwardRule(ForwardRule node) =>
      _inner.visitForwardRule(node.toUnsafeWrapper);
  JSAny? visitFunctionRule(FunctionRule node) =>
      _inner.visitFunctionRule(node.toUnsafeWrapper);
  JSAny? visitIfRule(IfRule node) => _inner.visitIfRule(node.toUnsafeWrapper);
  JSAny? visitImportRule(ImportRule node) =>
      _inner.visitImportRule(node.toUnsafeWrapper);
  JSAny? visitIncludeRule(IncludeRule node) =>
      _inner.visitIncludeRule(node.toJS);
  JSAny? visitLoudComment(LoudComment node) =>
      _inner.visitLoudComment(node.toJS);
  JSAny? visitMediaRule(MediaRule node) =>
      _inner.visitMediaRule(node.toUnsafeWrapper);
  JSAny? visitMixinRule(MixinRule node) =>
      _inner.visitMixinRule(node.toUnsafeWrapper);
  JSAny? visitReturnRule(ReturnRule node) =>
      _inner.visitReturnRule(node.toUnsafeWrapper);
  JSAny? visitSilentComment(SilentComment node) =>
      _inner.visitSilentComment(node.toUnsafeWrapper);
  JSAny? visitStyleRule(StyleRule node) =>
      _inner.visitStyleRule(node.toUnsafeWrapper);
  JSAny? visitStylesheet(Stylesheet node) =>
      _inner.visitStylesheet(node.toUnsafeWrapper);
  JSAny? visitSupportsRule(SupportsRule node) =>
      _inner.visitSupportsRule(node.toUnsafeWrapper);
  JSAny? visitUseRule(UseRule node) =>
      _inner.visitUseRule(node.toUnsafeWrapper);
  JSAny? visitVariableDeclaration(VariableDeclaration node) =>
      _inner.visitVariableDeclaration(node.toUnsafeWrapper);
  JSAny? visitWarnRule(WarnRule node) =>
      _inner.visitWarnRule(node.toUnsafeWrapper);
  JSAny? visitWhileRule(WhileRule node) =>
      _inner.visitWhileRule(node.toUnsafeWrapper);
}

extension type JSStatementVisitorObject._(JSObject _) {
  external JSAny? visitAtRootRule(UnsafeDartWrapper<AtRootRule> node);
  external JSAny? visitAtRule(UnsafeDartWrapper<AtRule> node);
  external JSAny? visitContentBlock(UnsafeDartWrapper<ContentBlock> node);
  external JSAny? visitContentRule(UnsafeDartWrapper<ContentRule> node);
  external JSAny? visitDebugRule(UnsafeDartWrapper<DebugRule> node);
  external JSAny? visitDeclaration(UnsafeDartWrapper<Declaration> node);
  external JSAny? visitEachRule(UnsafeDartWrapper<EachRule> node);
  external JSAny? visitErrorRule(UnsafeDartWrapper<ErrorRule> node);
  external JSAny? visitExtendRule(UnsafeDartWrapper<ExtendRule> node);
  external JSAny? visitForRule(UnsafeDartWrapper<ForRule> node);
  external JSAny? visitForwardRule(UnsafeDartWrapper<ForwardRule> node);
  external JSAny? visitFunctionRule(UnsafeDartWrapper<FunctionRule> node);
  external JSAny? visitIfRule(UnsafeDartWrapper<IfRule> node);
  external JSAny? visitImportRule(UnsafeDartWrapper<ImportRule> node);
  external JSAny? visitIncludeRule(UnsafeDartWrapper<IncludeRule> node);
  external JSAny? visitLoudComment(UnsafeDartWrapper<LoudComment> node);
  external JSAny? visitMediaRule(UnsafeDartWrapper<MediaRule> node);
  external JSAny? visitMixinRule(UnsafeDartWrapper<MixinRule> node);
  external JSAny? visitReturnRule(UnsafeDartWrapper<ReturnRule> node);
  external JSAny? visitSilentComment(UnsafeDartWrapper<SilentComment> node);
  external JSAny? visitStyleRule(UnsafeDartWrapper<StyleRule> node);
  external JSAny? visitStylesheet(UnsafeDartWrapper<Stylesheet> node);
  external JSAny? visitSupportsRule(UnsafeDartWrapper<SupportsRule> node);
  external JSAny? visitUseRule(UnsafeDartWrapper<UseRule> node);
  external JSAny? visitVariableDeclaration(
      UnsafeDartWrapper<VariableDeclaration> node);
  external JSAny? visitWarnRule(UnsafeDartWrapper<WarnRule> node);
  external JSAny? visitWhileRule(UnsafeDartWrapper<WhileRule> node);
}
