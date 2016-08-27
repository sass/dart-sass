// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/css/node.dart';
import '../ast/sass/expression.dart';
import '../ast/sass/statement.dart';
import '../ast/selector.dart';
import '../environment.dart';
import '../extend/extender.dart';
import '../parser.dart';
import '../value.dart';
import 'interface/statement.dart';
import 'interface/expression.dart';

class PerformVisitor extends StatementVisitor
    implements ExpressionVisitor<Value> {
  final Environment _environment;

  /// The current selector, if any.
  CssValue<SelectorList> _selector;

  /// The current media queries, if any.
  List<CssMediaQuery> _mediaQueries;

  /// The root stylesheet node.
  CssStylesheet _root;

  /// The current parent node in the output CSS tree.
  CssParentNode _parent;

  /// The name of the current declaration parent.
  String _declarationName;

  final _extender = new Extender();

  PerformVisitor() : this._(new Environment());

  PerformVisitor._(this._environment);

  void visit(node) {
    if (node is Statement) {
      node.accept(this);
    } else {
      (node as Expression).accept(this);
    }
  }

  // ## Statements

  CssStylesheet visitStylesheet(Stylesheet node) {
    _root = new CssStylesheet(span: node.span);
    _parent = _root;
    super.visitStylesheet(node);
    return _root;
  }

  void visitComment(Comment node) {
    if (node.isSilent) return;
    _parent.addChild(new CssComment(node.text, span: node.span));
  }

  void visitDeclaration(Declaration node) {
    var name = _performInterpolation(node.name);
    if (_declarationName != null) {
      name = new CssValue("$_declarationName-${name.value}", span: name.span);
    }
    var cssValue = node.value == null ? null : _performExpression(node.value);

    // If the value is an empty list, preserve it, because converting it to CSS
    // will throw an error that we want the user to see.
    if (cssValue != null &&
        (!cssValue.value.isBlank || cssValue.value is SassList)) {
      _parent.addChild(new CssDeclaration(name, cssValue, span: node.span));
    }

    if (node.children != null) {
      var oldDeclarationName = _declarationName;
      _declarationName = name.value;
      super.visitDeclaration(node);
      _declarationName = oldDeclarationName;
    }
  }

  void visitExtendRule(ExtendRule node) {
    var targetText = _performInterpolation(node.selector);

    // TODO: recontextualize parse errors.
    // TODO: disallow parent selectors.
    var simple = new Parser(targetText.value).parseSimpleSelector();
    _extender.addExtension(_selector.value, simple);
  }

  void visitAtRule(AtRule node) {
    var value = node.value == null
        ? null
        : _performInterpolation(node.value, trim: true);

    if (node.children == null) {
      _parent.addChild(new CssAtRule(node.name, value: value, span: node.span));
    }

    _withParent(new CssAtRule(node.name, value: value, span: node.span), () {
      if (_selector == null) {
        super.visitAtRule(node);
      } else {
        // If we're in a style rule, copy it into the at-rule so that
        // declarations immediately inside it have somewhere to go.
        //
        // For example, "a {@foo {b: c}}" should produce "@foo {a {b: c}}".
        _withParent(
            new CssStyleRule(_selector),
            () => super.visitAtRule(node),
            removeIfEmpty: true);
      }
    },
        through: (node) => node is CssStyleRule);
  }

  void visitMediaRule(MediaRule node) {
    var queryIterable = node.queries.map(_visitMediaQuery);
    var queries = _mediaQueries == null
        ? new List<CssMediaQuery>.unmodifiable(queryIterable)
        : _mergeMediaQueries(_mediaQueries, queryIterable);
    if (queries.isEmpty) return;

    _withParent(new CssMediaRule(queries, span: node.span), () {
      _withMediaQueries(queries, () {
        if (_selector == null) {
          super.visitMediaRule(node);
        } else {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          _withParent(
              new CssStyleRule(_selector),
              () => super.visitMediaRule(node),
              removeIfEmpty: true);
        }
      });
    },
        through: (node) => node is CssStyleRule || node is CssMediaRule,
        removeIfEmpty: true);
  }

  List<CssMediaQuery> _mergeMediaQueries(
      Iterable<CssMediaQuery> queries1, Iterable<CssMediaQuery> queries2) {
    return new List.unmodifiable(queries1.expand/*<CssMediaQuery>*/((query1) {
      return queries2.map((query2) => query1.merge(query2));
    }).where((query) => query != null));
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
    var parsedSelector = new Parser(selectorText.value).parseSelector();

    // TOOD: catch errors and point them to node.selector
    parsedSelector = parsedSelector.resolveParentSelectors(_selector?.value);

    // TODO: catch errors and re-contextualize them relative to
    // [node.selector.span.start].
    var selector = new CssValue<SelectorList>(parsedSelector,
        span: node.selector.span);

    _withParent(
        _extender.addSelector(selector, span: node.span),
        () => _withSelector(selector, () => super.visitStyleRule(node)),
        through: (node) => node is CssStyleRule,
        removeIfEmpty: true);
  }

  void visitVariableDeclaration(VariableDeclaration node) {
    _environment.setVariable(
        node.name, node.expression.accept(this),
        global: node.isGlobal);
  }

  // ## Expressions

  Value visitVariableExpression(VariableExpression node) {
    var result = _environment.getVariable(node.name);
    if (result != null) return result;

    // TODO: real exception
    throw node.span.message("undefined variable");
  }

  Value visitUnaryOperatorExpression(UnaryOperatorExpression node) {
    var operand = node.operand.accept(this);
    switch (node.operator) {
      case UnaryOperator.plus: return operand.unaryPlus();
      case UnaryOperator.minus: return operand.unaryMinus();
      case UnaryOperator.divide: return operand.unaryDivide();
      case UnaryOperator.not: return operand.unaryNot();
      default: throw new StateError("Unknown unary operator ${node.operator}.");
    }
  }

  SassIdentifier visitIdentifierExpression(IdentifierExpression node) =>
      new SassIdentifier(visitInterpolationExpression(node.text).text);

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      new SassBoolean(node.value);

  SassNumber visitNumberExpression(NumberExpression node) =>
      new SassNumber(node.value);

  SassColor visitColorExpression(ColorExpression node) => node.value;

  SassString visitInterpolationExpression(InterpolationExpression node) {
    return new SassString(node.contents.map((value) {
      if (value is String) return value;
      return (value as Expression).accept(this);
    }).join());
  }

  SassList visitListExpression(ListExpression node) => new SassList(
      node.contents.map((expression) => expression.accept(this)),
      node.separator,
      bracketed: node.isBracketed);

  SassMap visitMapExpression(MapExpression node) {
    var map = <Value, Value>{};
    for (var pair in node.pairs) {
      var keyValue = pair.first.accept(this);
      var valueValue = pair.last.accept(this);
      if (map.containsKey(keyValue)) {
        throw pair.first.span.message('Duplicate key.');
      }
      map[keyValue] = valueValue;
    }
    return new SassMap(map);
  }

  SassString visitStringExpression(StringExpression node) =>
      visitInterpolationExpression(node.text);

  // ## Utilities

  CssValue<String> _performInterpolation(
      InterpolationExpression interpolation, {bool trim: false}) {
    var result = visitInterpolationExpression(interpolation).text;
    return new CssValue(trim ? result.trim() : result,
        span: interpolation.span);
  }

  CssValue<Value> _performExpression(Expression expression) =>
      new CssValue(expression.accept(this), span: expression.span);

  /*=T*/ _withParent/*<S extends CssParentNode, T>*/(
      /*=S*/ node, /*=T*/ callback(),
      {bool through(CssNode node), bool removeIfEmpty: false}) {
    var oldParent = _parent;

    // Go up through parents that match [through].
    var parent = _parent;
    if (through != null) {
      while (through(parent)) {
        parent = parent.parent;
      }
    }

    parent.addChild(node);
    _parent = node;
    var result = _environment.scope(callback);
    if (removeIfEmpty && node.children.isEmpty) node.remove();
    _parent = oldParent;

    return result;
  }

  /*=T*/ _withSelector/*<T>*/(CssValue<SelectorList> selector,
      /*=T*/ callback()) {
    var oldSelector = _selector;
    _selector = selector;
    var result = callback();
    _selector = oldSelector;
    return result;
  }

  /*=T*/ _withMediaQueries/*<T>*/(List<CssMediaQuery> queries,
      /*=T*/ callback()) {
    var oldMediaQueries = _mediaQueries;
    _mediaQueries = queries;
    var result = callback();
    _mediaQueries = oldMediaQueries;
    return result;
  }
}
