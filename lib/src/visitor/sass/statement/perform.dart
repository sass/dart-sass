// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../../ast/css/node.dart';
import '../../../ast/sass/expression.dart';
import '../../../ast/sass/statement.dart';
import '../../../ast/selector.dart';
import '../../../environment.dart';
import '../../../mutable_node.dart';
import '../../../parser.dart';
import '../../../value.dart';
import '../expression/perform.dart';
import '../statement.dart';

class PerformVisitor extends StatementVisitor {
  final Environment _environment;
  final PerformExpressionVisitor _expressionVisitor;

  /// The innermost containing style rule, if one exists.
  ///
  /// This will always have an empty list of children.
  CssStyleRule _styleRule;

  /// The innermost containing media rule, if one exists.
  ///
  /// This will always have an empty list of children.
  CssMediaRule _mediaRule;

  /// A mutable view of the root stylesheet node.
  MutableNode<CssNode, CssStylesheet> _root;

  /// A mutable view of the current parent node in the output CSS tree.
  MutableNode<CssNode, CssNode> _parent;
  
  PerformVisitor() : this._(new Environment());

  PerformVisitor._(Environment environment)
      : _environment = environment,
        _expressionVisitor = new PerformExpressionVisitor(environment);

  void visit(Statement node) => node.accept(this);

  CssStylesheet visitStylesheet(Stylesheet node) {
    _root = new MutableNode<CssNode, CssStylesheet>.root(
        new CssStylesheet(const [], span: node.span));
    _parent = _root;
    super.visitStylesheet(node);
    return _root.build();
  }

  void visitComment(Comment node) {
    if (node.isSilent) return;
    _parent.add(new CssComment(node.text, span: node.span));
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

    _parent.add(new CssDeclaration(name, cssValue, span: node.span));
  }

  void visitAtRule(AtRule node) {
    var value = node.value == null
        ? null
        : _performInterpolation(node.value, trim: true);

    if (node.children == null) {
      _parent.add(new CssAtRule(node.name, value: value, span: node.span));
    }

    _withParent(
        new CssAtRule(node.name, value: value, span: node.span),
        () => super.visitAtRule(node),
        through: (node) => node is CssStyleRule);
  }

  void visitMediaRule(MediaRule node) {
    var queries = node.queries.map(_visitMediaQuery);
    if (_mediaRule != null) {
      queries = _mergeMediaQueries(_mediaRule.queries, queries);
    }
    if (queries.isEmpty) return;

    var rule = new CssMediaRule(queries, const [], span: node.span);
    _withParent(rule, () {
      _withMediaRule(rule, () => super.visitMediaRule(node));
      if (_parent.children.isEmpty) _parent.remove();
    }, through: (node) => node is CssStyleRule || node is CssMediaRule);
  }

  List<CssMediaQuery> _mergeMediaQueries(
      Iterable<CssMediaQuery> queries1, Iterable<CssMediaQuery> queries2) {
    return queries1.expand/*<CssMediaQuery>*/((query1) {
      return queries2.map((query2) => query1.merge(query2));
    }).where((query) => query != null).toList();
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
    if (_styleRule != null) {
      // TODO: semantically resolve parent references.
      selectorText = new CssValue(
          "${_styleRule.selector.value} ${selectorText.value}",
          span: node.selector.span);
    }

    // TODO: catch errors and re-contextualize them relative to
    // [node.selector.span.start].
    var selector = new CssValue<SelectorList>(
        new Parser(selectorText.value).parseSelector(),
        span: node.selector.span);

    var rule = new CssStyleRule(selector, const [], span: node.span);
    _withParent(rule, () {
      _withStyleRule(rule, () => super.visitStyleRule(node));
      if (_parent.children.isEmpty) _parent.remove();
    }, through: (node) => node is CssStyleRule);
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

  /*=T*/ _withParent/*<S extends CssNode, T>*/(CssNode/*=S*/ node,
      /*=T*/ callback(), {bool through(CssNode node)}) {
    var oldParent = _parent;

    // Go up through parents that match [through].
    var parent = _parent;
    if (through != null) {
      while (through(parent.node)) {
        parent = parent.parent;
      }
    }

    _parent = parent.add(node);
    var result = _environment.scope(callback);
    _parent = oldParent;

    return result;
  }

  /*=T*/ _withStyleRule/*<T>*/(CssStyleRule rule, /*=T*/ callback()) {
    var oldStyleRule = _styleRule;
    _styleRule = rule;
    var result = callback();
    _styleRule = oldStyleRule;
    return result;
  }

  /*=T*/ _withMediaRule/*<T>*/(CssMediaRule rule, /*=T*/ callback()) {
    var oldMediaRule = _mediaRule;
    _mediaRule = rule;
    var result = callback();
    _mediaRule = oldMediaRule;
    return result;
  }
}
