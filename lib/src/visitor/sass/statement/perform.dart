// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../../../ast/css/node.dart';
import '../../../ast/sass/expression.dart';
import '../../../ast/sass/statement.dart';
import '../../../environment.dart';
import '../../../utils.dart';
import '../../../value.dart';
import '../expression/perform.dart';
import '../statement.dart';

class PerformVisitor extends StatementVisitor {
  final Environment _environment;
  final PerformExpressionVisitor _expressionVisitor;
  final _styleRules = <CssStyleRule>[];

  /// These are linked lists so that we can efficiently insert the style rules
  /// before their nested children.
  final _children = [new LinkedList<LinkedListValue<CssNode>>()];

  PerformVisitor() : this._(new Environment());

  PerformVisitor._(Environment environment)
      : _environment = environment,
        _expressionVisitor = new PerformExpressionVisitor(environment);

  void visit(Statement node) => node.accept(this);

  CssStylesheet visitStylesheet(Stylesheet node) {
    super.visitStylesheet(node);
    return new CssStylesheet(_children.single.map((entry) => entry.value),
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

  void visitStyleRule(StyleRule node) {
    var selector = _performInterpolation(node.selector, trim: true);
    if (_styleRules.isNotEmpty) {
      selector = new CssValue(
          "${_styleRules.last.selector.value} ${selector.value}",
          span: node.selector.span);
    }

    // This allows us to follow Ruby Sass's behavior of always putting the style
    // rule before any of its children.
    var insertionPoint = _children.first.isEmpty ? null : _children.first.last;

    _styleRules.add(new CssStyleRule(selector, [], span: node.span));
    var children = _collectChildren(() => super.visitStyleRule(node));
    _styleRules.removeLast();
    if (children.isEmpty) return;

    var rule = new CssStyleRule(selector, children, span: node.span);
    if (insertionPoint == null) {
      _children.first.addFirst(new LinkedListValue(rule));
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

  void _addChild(CssNode node) {
    _children.last.add(new LinkedListValue(node));
  }

  /// Implicitly adds an environment scope.
  Iterable<CssNode> _collectChildren(void callback()) {
    _children.add(new LinkedList<LinkedListValue<CssNode>>());
    _environment.scope(callback);
    return _children.removeLast().map((entry) => entry.value);
  }
}
