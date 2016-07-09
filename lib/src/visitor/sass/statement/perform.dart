// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../../../ast/css/node.dart';
import '../../../ast/sass/expression.dart';
import '../../../ast/sass/statement.dart';
import '../../../ast/selector.dart';
import '../../../environment.dart';
import '../../../parser.dart';
import '../../../utils.dart';
import '../../../value.dart';
import '../expression/perform.dart';
import '../statement.dart';

class PerformVisitor extends StatementVisitor {
  final Environment _environment;
  final PerformExpressionVisitor _expressionVisitor;

  /// Style rules containing the currently visited node, from outermost to
  /// innermost.
  var _styleRules = <CssStyleRule>[];

  /// The children of the root stylesheet node.
  ///
  /// This is a linked list so that we can efficiently insert style rules before
  /// their nested children.
  final _rootChildren = new LinkedList<LinkedListValue<CssNode>>();

  /// The list of children to which style rules should be added.
  ///
  /// This is usually the same as [_rootChildren], but it may also be the
  /// children of an at-rule.
  LinkedList<LinkedListValue<CssNode>> _outerChildren;

  /// The list of children of the innermost AST node.
  ///
  /// This may be the same as [_outerChildren] if the innermost AST node is an
  /// at-rule or the root stylesheet.
  LinkedList<LinkedListValue<CssNode>> _innerChildren;
  
  PerformVisitor() : this._(new Environment());

  PerformVisitor._(Environment environment)
      : _environment = environment,
        _expressionVisitor = new PerformExpressionVisitor(environment) {
    _outerChildren = _rootChildren;
    _innerChildren = _outerChildren;
  }

  void visit(Statement node) => node.accept(this);

  CssStylesheet visitStylesheet(Stylesheet node) {
    super.visitStylesheet(node);
    return new CssStylesheet(_rootChildren.map((entry) => entry.value),
        span: node.span);
  }

  void visitComment(Comment node) {
    if (node.isSilent) return;
    _addChild(new CssComment(node.text, span: node.span));
  }

  void visitDeclaration(Declaration node) {
    var name = _performInterpolation(node.name);
    var cssValue = _performExpression(node.value);
    var value = cssValue.value;

    // Don't abort for an empty list because converting it to CSS will throw an
    // error that we want to user to see.
    if (value.isBlank &&
        !(value is SassList && value.contents.isEmpty)) {
      return;
    }

    _addChild(new CssDeclaration(name, cssValue, span: node.span));
  }

  void visitAtRule(AtRule node) {
    var value = node.value == null
        ? null
        : _performInterpolation(node.value, trim: true);

    var children = node.children == null
        ? null
        : _atRuleChildren(() => super.visitAtRule(node));

    _addChild(
        new CssAtRule(node.name,
            value: value, children: children, span: node.span),
        outer: node.children != null);
  }

  void visitMediaRule(MediaRule node) {
    _addChild(
        new CssMediaRule(
            node.queries.map(_visitMediaQuery),
            _atRuleChildren(() => super.visitMediaRule(node)),
            span: node.span),
        outer: true);
  }

  CssMediaQuery _visitMediaQuery(MediaQuery query) {
    var modifier = query.modifier == null
        ? null
        : _performInterpolation(query.modifier);

    var type = query.type == null
        ? null
        : _performInterpolation(query.type);

    var features = query.features
        .map((feature) => _performInterpolation(feature));

    if (type == null) return new CssMediaQuery.condition(features);
    return new CssMediaQuery(type, modifier: modifier, features: features);
  }

  void visitStyleRule(StyleRule node) {
    var selectorText = _performInterpolation(node.selector, trim: true);
    if (_styleRules.isNotEmpty) {
      // TODO: semantically resolve parent references.
      selectorText = new CssValue(
          "${_styleRules.last.selector.value} ${selectorText.value}",
          span: node.selector.span);
    }

    // TODO: catch errors and re-contextualize them relative to
    // [node.selector.span.start].
    var selector = new CssValue<SelectorList>(
        new Parser(selectorText.value).parseSelector(),
        span: node.selector.span);

    // This allows us to follow Ruby Sass's behavior of always putting the style
    // rule before any of its children.
    var insertionPoint = _outerChildren.isEmpty ? null : _outerChildren.last;

    _styleRules.add(new CssStyleRule(selector, [], span: node.span));
    var children = _collectChildren(() => super.visitStyleRule(node));
    _styleRules.removeLast();
    if (children.isEmpty) return;

    var rule = new CssStyleRule(selector, children, span: node.span);
    if (insertionPoint == null) {
      _outerChildren.addFirst(new LinkedListValue(rule));
    } else {
      insertionPoint.insertAfter(new LinkedListValue(rule));
    }
  }

  void visitVariableDeclaration(VariableDeclaration node) {
    _environment.setVariable(
        node.name, node.expression.accept(_expressionVisitor),
        global: node.isGlobal);
  }

  CssValue<String> _performInterpolation(
      InterpolationExpression interpolation, {bool trim: false}) {
    var result = _expressionVisitor.visitInterpolationExpression(interpolation)
        .text;
    return new CssValue(trim ? result.trim() : result);
  }

  CssValue<Value> _performExpression(Expression expression) =>
      new CssValue(expression.accept(_expressionVisitor));

  void _addChild(CssNode node, {bool outer: false}) {
    var list = outer ? _outerChildren : _innerChildren;
    list.add(new LinkedListValue(node));
  }

  /*=T*/ _resetStyleRules/*<T>*/(/*=T*/ callback()) {
    var oldStyleRules = _styleRules;
    _styleRules = [];
    var result = callback();
    _styleRules = oldStyleRules;
    return result;
  }

  /// Like [_collectChildren], but handles bubbling.
  Iterable<CssNode> _atRuleChildren(void callback()) {
    if (_styleRules.isEmpty) return _collectChildren(callback);

    return _scope(() {
      _outerChildren = new LinkedList();
      _innerChildren = new LinkedList();

      callback();

      if (_innerChildren.isNotEmpty) {
        _outerChildren.addFirst(new LinkedListValue(new CssStyleRule(
            _styleRules.last.selector,
            _innerChildren.map((node) => node.value),
            span: _styleRules.last.span)));
      }

      return _outerChildren.map((node) => node.value);
    });
  }

  Iterable<CssNode> _collectChildren(void callback()) {
    return _scope(() {
      _innerChildren = new LinkedList();
      callback();
      return _innerChildren.map((node) => node.value);
    });
  }

  /// Runs [callback] within a nested scope.
  ///
  /// This creates an environment scope. When [callback] is done running, it
  /// restores [_innerChildren] and [_outerChildren] to the values they had
  /// when this was called.
  /*=T*/ _scope/*<T>*/(/*=T*/ callback()) {
    var oldOuter = _outerChildren;
    var oldInner = _innerChildren;
    var result = _environment.scope(callback);
    _outerChildren = oldOuter;
    _innerChildren = oldInner;
    return result;
  }
}
