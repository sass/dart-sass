// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../callable.dart';
import '../environment.dart';
import '../extend/extender.dart';
import '../parser.dart';
import '../utils.dart';
import '../value.dart';
import 'interface/statement.dart';
import 'interface/expression.dart';

class PerformVisitor extends StatementVisitor
    implements ExpressionVisitor<Value> {
  Environment _environment;

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

  PerformVisitor([Environment environment])
      : _environment = environment ?? new Environment();

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

  void visitContent(Content node) {
    var block = _environment.contentBlock;
    if (block == null) return;

    _withEnvironment(_environment.contentEnvironment, () {
      for (var statement in block) {
        statement.accept(this);
      }
    });
  }

  void visitDeclaration(Declaration node) {
    var name = _interpolationToValue(node.name);
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
    var targetText = _interpolationToValue(node.selector);

    // TODO: recontextualize parse errors.
    // TODO: disallow parent selectors.
    var simple = new Parser(targetText.value).parseSimpleSelector();
    _extender.addExtension(_selector.value, simple);
  }

  void visitAtRule(AtRule node) {
    var value = node.value == null
        ? null
        : _interpolationToValue(node.value, trim: true);

    if (node.children == null) {
      _parent.addChild(new CssAtRule(node.name,
          childless: true, value: value, span: node.span));
      return;
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

  void visitFunctionDeclaration(FunctionDeclaration node) {
    _environment.setFunction(
        new UserDefinedCallable(node, _environment.closure()));
  }

  void visitInclude(Include node) {
    var mixin = _environment.getMixin(node.name) as UserDefinedCallable;
    if (mixin == null) throw node.span.message("Undefined mixin.");

    if (node.children != null &&
        !(mixin.declaration as MixinDeclaration).hasContent) {
      throw node.span.message("Mixin doesn't accept a content block.");
    }

    Value callback() {
      for (var statement in mixin.declaration.children) {
        statement.accept(this);
      }
      return null;
    }

    if (node.children == null) {
      _runUserDefinedCallable(node, mixin, callback);
    } else {
      var environment = _environment.closure();
      _runUserDefinedCallable(node, mixin, () {
        _environment.withContent(node.children, environment, callback);
      });
    }
  }

  void visitMixinDeclaration(MixinDeclaration node) {
    _environment.setMixin(
        new UserDefinedCallable(node, _environment.closure()));
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
        : _interpolationToValue(query.modifier);

    var type = query.type == null
        ? null
        : _interpolationToValue(query.type);

    var features = query.features
        .map((feature) => _interpolationToValue(feature));

    if (type == null) return new CssMediaQuery.condition(features);
    return new CssMediaQuery(type, modifier: modifier, features: features);
  }

  Value visitReturn(Return node) => node.expression.accept(this);

  void visitStyleRule(StyleRule node) {
    var selectorText = _interpolationToValue(node.selector, trim: true);
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
      new SassIdentifier(_performInterpolation(node.text));

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      new SassBoolean(node.value);

  SassNumber visitNumberExpression(NumberExpression node) =>
      new SassNumber(node.value);

  SassColor visitColorExpression(ColorExpression node) => node.value;

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

  Value visitFunctionExpression(FunctionExpression node) {
    var plainName = node.name.asPlain;
    if (plainName != null) {
      var function = _environment.getFunction(plainName);
      if (function != null) {
        if (function is BuiltInCallable) {
          return _runBuiltInCallable(node, function);
        } else if (function is UserDefinedCallable) {
          return _runUserDefinedCallable(node, function, () {
            for (var statement in function.declaration.children) {
              var returnValue = statement.accept(this);
              if (returnValue is Value) return returnValue;
            }

            throw function.declaration.span.message(
                "Function finished without @return.");
          });
        } else {
          return null;
        }
      }
    }

    if (node.arguments.named.isNotEmpty || node.arguments.keywordRest != null) {
      throw node.span.message(
          "Plain CSS functions don't support keyword arguments.");
    }

    var name = _performInterpolation(node.name);
    var arguments = node.arguments.positional
        .map((expression) => expression.accept(this)).toList();
    // TODO: if rest is an arglist that has keywords, error out.
    var rest = node.arguments.rest?.accept(this);
    if (rest != null) arguments.add(rest);
    return new SassIdentifier("$name(${arguments.join(', ')})");
  }

  Value _runUserDefinedCallable(CallableInvocation invocation,
      UserDefinedCallable callable, Value run()) {
    var pair = _evaluateArguments(invocation);
    var positional = pair.first;
    var named = pair.last;

    return _withEnvironment(callable.environment, () => _environment.scope(() {
      _verifyArguments(positional, named, callable.arguments, invocation.span);

      // TODO: if we get here and there are no rest params involved, mark the
      // callable as fast-path and don't do error checking or extra allocations
      // for future calls.
      var declaredArguments = callable.arguments.arguments;
      var minLength = math.min(positional.length, declaredArguments.length);
      for (var i = 0; i < minLength; i++) {
        _environment.setVariable(declaredArguments[i].name, positional[i]);
      }

      for (var i = positional.length; i < declaredArguments.length; i++) {
        var argument = declaredArguments[i];
        _environment.setVariable(argument.name,
            named.remove(argument.name) ??
                argument.defaultValue?.accept(this));
      }

      // TODO: use a full ArgList object
      if (callable.arguments.restArgument != null) {
        var rest = positional.length > declaredArguments.length
            ? positional.sublist(declaredArguments.length)
            : const <Value>[];
        _environment.setVariable(callable.arguments.restArgument,
            new SassList(rest, ListSeparator.comma));
      }

      return run();
    }));
  }

  Value _runBuiltInCallable(CallableInvocation invocation,
      BuiltInCallable callable) {
    var pair = _evaluateArguments(invocation);
    var positional = pair.first;
    var named = pair.last;

    _verifyArguments(positional, named, callable.arguments, invocation.span);

    var declaredArguments = callable.arguments.arguments;
    for (var i = positional.length; i < declaredArguments.length; i++) {
      var argument = declaredArguments[i];
      positional.add(named.remove(argument.name) ??
          argument.defaultValue?.accept(this));
    }

    // TODO: use a full ArgList object
    if (callable.arguments.restArgument != null) {
      var rest = positional.length > declaredArguments.length
          ? positional.sublist(declaredArguments.length)
          : const <Value>[];
      positional.add(new SassList(rest, ListSeparator.comma));
    }

    return callable.callback(positional);
  }

  Pair<List<Value>, Map<String, Value>> _evaluateArguments(
      CallableInvocation invocation) {
    var positional = invocation.arguments.positional
        .map((expression) => expression.accept(this)).toList();
    var named = normalizedMapMap/*<String, Expression, Value>*/(
        invocation.arguments.named,
        value: (_, expression) => expression.accept(this));

    if (invocation.arguments.rest == null) return new Pair(positional, named);

    var rest = invocation.arguments.rest.accept(this);
    if (rest is SassMap) {
      _addRestMap(named, rest, invocation.span);
    } else if (rest is SassList) {
      positional.addAll(rest.asList());
    } else {
      positional.add(rest);
    }

    if (invocation.arguments.keywordRest == null) {
      return new Pair(positional, named);
    }

    var keywordRest = invocation.arguments.keywordRest.accept(this);
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, invocation.span);
      return new Pair(positional, named);
    } else {
      throw invocation.span.message(
          "Variable keyword arguments must be a map (was $keywordRest).");
    }
  }

  void _addRestMap(Map<String, Value> values, SassMap map, FileSpan span) {
    map.contents.forEach((key, value) {
      if (key is SassIdentifier) {
        values[key.text] = value;
      } else if (key is SassString) {
        values[key.text] = value;
      } else {
        throw span.message(
            "Variable keyword argument map must have string keys.\n"
            "$key is not a string in $value.");
      }
    });
  }

  void _verifyArguments(List<Value> positional, Map<String, Value> named,
      ArgumentDeclaration arguments, FileSpan span) {
    for (var i = 0; i < arguments.arguments.length; i++) {
      var argument = arguments.arguments[i];
      if (i < positional.length) {
        if (named.containsKey(argument.name)) {
          throw span.message(
              "Argument \$${argument.name} was passed both by position and by "
                "name.");
        }
      } else if (argument.defaultValue == null &&
          !named.containsKey(argument.name)) {
        throw span.message("Missing argument \$${argument.name}.");
      }
    }

    if (arguments.restArgument != null) return;

    if (positional.length > arguments.arguments.length) {
      throw span.message(
          "Only ${arguments.arguments.length} "
            "${pluralize('argument', arguments.arguments.length)} allowed, "
            "but ${positional.length} "
            "${pluralize('was', positional.length, plural: 'were')} passed.");
    }

    if (arguments.arguments.length - positional.length < named.length) {
      var unknownNames = normalizedSet()
          ..addAll(named.keys)
          ..removeAll(arguments.arguments.map((argument) => argument.name));
      throw span.message(
          "No ${pluralize('argument', unknownNames.length)} named "
          "${toSentence(unknownNames.map((name) => "\$$name"), 'or')}.");
    }
  }

  SassString visitStringExpression(StringExpression node) =>
      new SassString(_performInterpolation(node.text));

  // ## Utilities

  /*=T*/ _withEnvironment/*<T>*/(Environment environment, /*=T*/ callback()) {
    var oldEnvironment = _environment;
    _environment = environment;
    var result = callback();
    _environment = oldEnvironment;
    return result;
  }

  CssValue<String> _interpolationToValue(
      Interpolation interpolation, {bool trim: false}) {
    var result = _performInterpolation(interpolation);
    return new CssValue(trim ? result.trim() : result,
        span: interpolation.span);
  }

  String _performInterpolation(Interpolation interpolation) {
    return interpolation.contents.map((value) {
      if (value is String) return value;
      return (value as Expression).accept(this);
    }).join();
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
