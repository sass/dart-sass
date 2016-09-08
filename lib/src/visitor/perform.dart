// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../ast/css.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../callable.dart';
import '../environment.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../parser.dart';
import '../utils.dart';
import '../value.dart';
import 'interface/statement.dart';
import 'interface/expression.dart';
import 'serialize.dart';

typedef _ScopeCallback(callback());

class PerformVisitor implements StatementVisitor, ExpressionVisitor<Value> {
  final List<String> _loadPaths;

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

  var _member = "root stylesheet";

  final _importPaths = <ImportRule, String>{};

  final _importedFiles = <String, Stylesheet>{};

  final _extender = new Extender();

  final _stack = <Frame>[];

  PerformVisitor({Iterable<String> loadPaths, Environment environment})
      : _loadPaths = loadPaths == null ? const [] : new List.from(loadPaths),
        _environment = environment ?? new Environment();

  void visit(node) {
    if (node is Statement) {
      node.accept(this);
    } else {
      (node as Expression).accept(this);
    }
  }

  // ## Statements

  CssStylesheet visitStylesheet(Stylesheet node) {
    _root = new CssStylesheet(node.span);
    _parent = _root;
    for (var child in node.children) {
      child.accept(this);
    }
    _extender.finalize();
    return _root;
  }

  void visitAtRootRule(AtRootRule node) {
    var query = node.query == null
        ? AtRootQuery.defaultQuery
        : new Parser(_performInterpolation(node.query)).parseAtRootQuery();

    var parent = _parent;
    var included = <CssParentNode>[];
    while (parent is! CssStylesheet) {
      if (!query.excludes(parent)) included.add(parent);
      parent = parent.parent;
    }
    var root = _trimIncluded(included);

    // If we didn't exclude any rules, we don't need to use the copies we might
    // have created.
    if (root == _parent) {
      for (var child in node.children) {
        child.accept(this);
      }
      return;
    }

    var innerCopy =
        included.isEmpty ? null : included.first.copyWithoutChildren();
    var outerCopy = innerCopy;
    for (var node in included.skip(1)) {
      var copy = node.copyWithoutChildren();
      copy.addChild(outerCopy);
      outerCopy = copy;
    }

    if (outerCopy != null) root.addChild(outerCopy);
    _scopeForAtRule(innerCopy ?? root, query)(() {
      for (var child in node.children) {
        child.accept(this);
      }
    });
  }

  CssParentNode _trimIncluded(List<CssParentNode> nodes) {
    var parent = _parent;
    int innermostContiguous;
    var i = 0;
    for (; i < nodes.length; i++) {
      while (parent != nodes[i]) {
        innermostContiguous = null;
        parent = parent.parent;
      }
      innermostContiguous ??= i;
      parent = parent.parent;
    }

    if (parent != _root) return _root;
    var root = nodes[innermostContiguous];
    nodes.removeRange(innermostContiguous, nodes.length);
    return root;
  }

  _ScopeCallback _scopeForAtRule(CssNode newParent, AtRootQuery query) {
    var scope = (callback()) {
      // We can't use [_withParent] here because it'll add the node to the tree
      // in the wrong place.
      var oldParent = _parent;
      _parent = newParent;
      _environment.scope(callback);
      _parent = oldParent;
    };

    if (query.excludesMedia) {
      var innerScope = scope;
      scope = (callback) => _withMediaQueries(null, () => innerScope(callback));
    }
    if (query.excludesRule) {
      var innerScope = scope;
      scope = (callback) => _withSelector(null, () => innerScope(callback));
    }

    return scope;
  }

  void visitComment(Comment node) {
    if (node.isSilent) return;
    _parent.addChild(new CssComment(node.text, node.span));
  }

  void visitContentRule(ContentRule node) {
    var block = _environment.contentBlock;
    if (block == null) return;

    _withStackFrame("@content", node.span, () {
      _withEnvironment(_environment.contentEnvironment, () {
        for (var statement in block) {
          statement.accept(this);
        }
      });
    });
  }

  void visitDebugRule(DebugRule node) {
    stderr.writeln("Line ${node.span.start.line + 1} DEBUG: "
        "${node.expression.accept(this)}");
  }

  void visitDeclaration(Declaration node) {
    if (_selector == null) {
      throw _exception(
          "Declarations may only be used within style rules.", node.span);
    }

    var name = _interpolationToValue(node.name);
    if (_declarationName != null) {
      name = new CssValue("$_declarationName-${name.value}", name.span);
    }
    var cssValue = node.value == null ? null : _performExpression(node.value);

    // If the value is an empty list, preserve it, because converting it to CSS
    // will throw an error that we want the user to see.
    if (cssValue != null &&
        (!cssValue.value.isBlank || cssValue.value is SassList)) {
      _parent.addChild(new CssDeclaration(name, cssValue, node.span));
    }

    if (node.children != null) {
      var oldDeclarationName = _declarationName;
      _declarationName = name.value;
      for (var child in node.children) {
        child.accept(this);
      }
      _declarationName = oldDeclarationName;
    }
  }

  void visitEachRule(EachRule node) {
    var list = node.list.accept(this);
    var setVariables = node.variables.length == 1
        ? (value) => _environment.setLocalVariable(node.variables.first, value)
        : (value) => _setMultipleVariables(node.variables, value);
    _environment.scope(() {
      for (var element in list.asList) {
        setVariables(element);
        for (var child in node.children) {
          child.accept(this);
        }
      }
    }, semiGlobal: true);
  }

  void _setMultipleVariables(List<String> variables, Value value) {
    var list = value.asList;
    var minLength = math.min(variables.length, list.length);
    for (var i = 0; i < minLength; i++) {
      _environment.setLocalVariable(variables[i], list[i]);
    }
    for (var i = minLength; i < variables.length; i++) {
      _environment.setLocalVariable(variables[i], sassNull);
    }
  }

  void visitErrorRule(ErrorRule node) {
    throw _exception(node.expression.accept(this).toString(), node.span);
  }

  void visitExtendRule(ExtendRule node) {
    if (_selector == null || _declarationName != null) {
      throw _exception(
          "@extend may only be used within style rules.", node.span);
    }

    var targetText = _interpolationToValue(node.selector);

    // TODO: recontextualize parse errors.
    // TODO: disallow parent selectors.
    var target = new Parser(targetText.value.trim()).parseSimpleSelector();
    _extender.addExtension(_selector.value, target, node);
  }

  void visitAtRule(AtRule node) {
    if (_declarationName != null) {
      throw _exception(
          "At-rules may not be used within nested declarations.", node.span);
    }

    var value = node.value == null
        ? null
        : _interpolationToValue(node.value, trim: true);

    if (node.children == null) {
      _parent.addChild(
          new CssAtRule(node.name, node.span, childless: true, value: value));
      return;
    }

    _withParent(new CssAtRule(node.name, node.span, value: value), () {
      if (_selector == null) {
        for (var child in node.children) {
          child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the at-rule so that
        // declarations immediately inside it have somewhere to go.
        //
        // For example, "a {@foo {b: c}}" should produce "@foo {a {b: c}}".
        _withParent(new CssStyleRule(_selector, _selector.span), () {
          for (var child in node.children) {
            child.accept(this);
          }
        });
      }
    }, through: (node) => node is CssStyleRule);
  }

  void visitForRule(ForRule node) {
    var from =
        _addExceptionSpan(() => node.from.accept(this).asInt, node.from.span);
    var to = _addExceptionSpan(() => node.to.accept(this).asInt, node.to.span);

    // TODO: coerce units
    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return;

    _environment.scope(() {
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(node.variable, new SassNumber(i));
        for (var child in node.children) {
          child.accept(this);
        }
      }
    }, semiGlobal: true);
  }

  void visitFunctionRule(FunctionRule node) {
    _environment
        .setFunction(new UserDefinedCallable(node, _environment.closure()));
  }

  void visitIfRule(IfRule node) {
    var condition = node.expression.accept(this);
    if (!condition.isTruthy) return;
    _environment.scope(() {
      for (var child in node.children) {
        child.accept(this);
      }
    }, semiGlobal: true);
  }

  void visitImportRule(ImportRule node) {
    var stylesheet = _loadImport(node);
    _withStackFrame("@import", node.span, () {
      _withEnvironment(_environment.global(), () {
        for (var statement in stylesheet.children) {
          statement.accept(this);
        }
      });
    });
  }

  Stylesheet _loadImport(ImportRule node) {
    var path = _importPaths.putIfAbsent(node, () {
      var path = p.fromUri(node.url);
      var extension = p.extension(path);
      var tryPath = extension == '.sass' || extension == '.scss'
          ? _tryImportPath
          : _tryImportPathWithExtensions;

      var base = p.dirname(p.fromUri(node.span.file.url));
      var resolved = tryPath(p.join(base, path));
      if (resolved != null) return resolved;

      for (var loadPath in _loadPaths) {
        var resolved = tryPath(p.join(loadPath, path));
        if (resolved != null) return resolved;
      }
    });

    if (path == null) {
      throw _exception("Can't find file to import.", node.span);
    }

    return _importedFiles.putIfAbsent(
        path,
        () => new Parser(new File(path).readAsStringSync(), url: p.toUri(path))
            .parse());
  }

  String _tryImportPathWithExtensions(String path) =>
      _tryImportPath(path + '.sass') ?? _tryImportPath(path + '.scss');

  String _tryImportPath(String path) {
    var partial = p.join(p.dirname(path), "_${p.basename(path)}");
    if (new File(partial).existsSync()) return partial;
    if (new File(path).existsSync()) return path;
    return null;
  }

  void visitIncludeRule(IncludeRule node) {
    var mixin = _environment.getMixin(node.name) as UserDefinedCallable;
    if (mixin == null) {
      throw _exception("Undefined mixin.", node.span);
    }

    if (node.children != null && !(mixin.declaration as MixinRule).hasContent) {
      throw _exception("Mixin doesn't accept a content block.", node.span);
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

  void visitMixinRule(MixinRule node) {
    _environment
        .setMixin(new UserDefinedCallable(node, _environment.closure()));
  }

  void visitMediaRule(MediaRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var queryIterable = node.queries.map(_visitMediaQuery);
    var queries = _mediaQueries == null
        ? new List<CssMediaQuery>.unmodifiable(queryIterable)
        : _mergeMediaQueries(_mediaQueries, queryIterable);
    if (queries.isEmpty) return;

    _withParent(new CssMediaRule(queries, node.span), () {
      _withMediaQueries(queries, () {
        if (_selector == null) {
          for (var child in node.children) {
            child.accept(this);
          }
        } else {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          _withParent(new CssStyleRule(_selector, _selector.span), () {
            for (var child in node.children) {
              child.accept(this);
            }
          });
        }
      });
    }, through: (node) => node is CssStyleRule || node is CssMediaRule);
  }

  List<CssMediaQuery> _mergeMediaQueries(
      Iterable<CssMediaQuery> queries1, Iterable<CssMediaQuery> queries2) {
    return new List.unmodifiable(queries1.expand/*<CssMediaQuery>*/((query1) {
      return queries2.map((query2) => query1.merge(query2));
    }).where((query) => query != null));
  }

  CssMediaQuery _visitMediaQuery(MediaQuery query) {
    var modifier =
        query.modifier == null ? null : _interpolationToValue(query.modifier);

    var type = query.type == null ? null : _interpolationToValue(query.type);

    var features =
        query.features.map((feature) => _interpolationToValue(feature));

    if (type == null) return new CssMediaQuery.condition(features);
    return new CssMediaQuery(type, modifier: modifier, features: features);
  }

  CssImport visitPlainImportRule(PlainImportRule node) =>
      new CssImport(node.url, node.span);

  Value visitReturnRule(ReturnRule node) => node.expression.accept(this);

  void visitStyleRule(StyleRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var selectorText = _interpolationToValue(node.selector, trim: true);
    var parsedSelector = new Parser(selectorText.value).parseSelector();
    parsedSelector = _addExceptionSpan(
        () => parsedSelector.resolveParentSelectors(_selector?.value),
        node.selector.span);

    // TODO: catch errors and re-contextualize them relative to
    // [node.selector.span.start].
    var selector =
        new CssValue<SelectorList>(parsedSelector, node.selector.span);

    _withParent(_extender.addSelector(selector, node.span), () {
      _withSelector(selector, () {
        for (var child in node.children) {
          child.accept(this);
        }
      });
    }, through: (node) => node is CssStyleRule);
  }

  void visitSupportsRule(SupportsRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Supports rules may not be used within nested declarations.",
          node.span);
    }

    var condition = new CssValue(
        _visitSupportsCondition(node.condition), node.condition.span);
    _withParent(new CssSupportsRule(condition, node.span), () {
      if (_selector == null) {
        for (var child in node.children) {
          child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the supports rule so that
        // declarations immediately inside @supports have somewhere to go.
        //
        // For example, "a {@supports (a: b) {b: c}}" should produce "@supports
        // (a: b) {a {b: c}}".
        _withParent(new CssStyleRule(_selector, _selector.span), () {
          for (var child in node.children) {
            child.accept(this);
          }
        });
      }
    }, through: (node) => node is CssStyleRule);
  }

  String _visitSupportsCondition(SupportsCondition condition) {
    if (condition is SupportsOperation) {
      return "${_parenthesize(condition.left, condition.operator)} "
          "${condition.operator} "
          "${_parenthesize(condition.right, condition.operator)}";
    } else if (condition is SupportsNegation) {
      return "not ${_parenthesize(condition.condition)}";
    } else if (condition is SupportsInterpolation) {
      return condition.expression.accept(this);
    } else if (condition is SupportsDeclaration) {
      return "(${condition.name.accept(this)}: ${condition.value.accept(this)})";
    } else {
      return null;
    }
  }

  String _parenthesize(SupportsCondition condition, [String operator]) {
    if ((condition is SupportsNegation) ||
        (condition is SupportsOperation &&
            (operator == null || operator != condition.operator))) {
      return "(${_visitSupportsCondition(condition)})";
    } else {
      return _visitSupportsCondition(condition);
    }
  }

  void visitVariableDeclaration(VariableDeclaration node) {
    _environment.setVariable(node.name, node.expression.accept(this),
        global: node.isGlobal);
  }

  void visitWarnRule(WarnRule node) {
    stderr.writeln("WARNING: ${valueToCss(node.expression.accept(this))}");
    for (var line in _stackTrace(node.span).toString().split("\n")) {
      stderr.writeln("         $line");
    }
  }

  void visitWhileRule(WhileRule node) {
    _environment.scope(() {
      while (node.condition.accept(this).isTruthy) {
        for (var child in node.children) {
          child.accept(this);
        }
      }
    }, semiGlobal: true);
  }

  // ## Expressions

  Value visitVariableExpression(VariableExpression node) {
    var result = _environment.getVariable(node.name);
    if (result != null) return result;

    // TODO: real exception
    throw _exception("Undefined variable.", node.span);
  }

  Value visitUnaryOperatorExpression(UnaryOperatorExpression node) {
    var operand = node.operand.accept(this);
    switch (node.operator) {
      case UnaryOperator.plus:
        return operand.unaryPlus();
      case UnaryOperator.minus:
        return operand.unaryMinus();
      case UnaryOperator.divide:
        return operand.unaryDivide();
      case UnaryOperator.not:
        return operand.unaryNot();
      default:
        throw new StateError("Unknown unary operator ${node.operator}.");
    }
  }

  SassIdentifier visitIdentifierExpression(IdentifierExpression node) =>
      new SassIdentifier(_performInterpolation(node.text));

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      new SassBoolean(node.value);

  SassNull visitNullExpression(NullExpression node) => sassNull;

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
        throw _exception('Duplicate key.', pair.first.span);
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

            throw _exception("Function finished without @return.",
                function.declaration.span);
          });
        } else {
          return null;
        }
      }
    }

    if (node.arguments.named.isNotEmpty || node.arguments.keywordRest != null) {
      throw _exception(
          "Plain CSS functions don't support keyword arguments.", node.span);
    }

    var name = _performInterpolation(node.name);
    var arguments = node.arguments.positional
        .map((expression) => expression.accept(this))
        .toList();
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

    return _withStackFrame(callable.name + "()", invocation.span, () {
      return _withEnvironment(callable.environment, () {
        return _environment.scope(() {
          _verifyArguments(
              positional, named, callable.arguments, invocation.span);

          // TODO: if we get here and there are no rest params involved, mark
          // the callable as fast-path and don't do error checking or extra
          // allocations for future calls.
          var declaredArguments = callable.arguments.arguments;
          var minLength = math.min(positional.length, declaredArguments.length);
          for (var i = 0; i < minLength; i++) {
            _environment.setVariable(declaredArguments[i].name, positional[i]);
          }

          for (var i = positional.length; i < declaredArguments.length; i++) {
            var argument = declaredArguments[i];
            _environment.setVariable(
                argument.name,
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
        });
      });
    });
  }

  Value _runBuiltInCallable(
      CallableInvocation invocation, BuiltInCallable callable) {
    var pair = _evaluateArguments(invocation);
    var positional = pair.first;
    var named = pair.last;

    _verifyArguments(positional, named, callable.arguments, invocation.span);

    var declaredArguments = callable.arguments.arguments;
    for (var i = positional.length; i < declaredArguments.length; i++) {
      var argument = declaredArguments[i];
      positional.add(
          named.remove(argument.name) ?? argument.defaultValue?.accept(this));
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
        .map((expression) => expression.accept(this))
        .toList();
    var named = normalizedMapMap/*<String, Expression, Value>*/(
        invocation.arguments.named,
        value: (_, expression) => expression.accept(this));

    if (invocation.arguments.rest == null) return new Pair(positional, named);

    var rest = invocation.arguments.rest.accept(this);
    if (rest is SassMap) {
      _addRestMap(named, rest, invocation.span);
    } else if (rest is SassList) {
      positional.addAll(rest.asList);
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
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).",
          invocation.span);
    }
  }

  void _addRestMap(Map<String, Value> values, SassMap map, FileSpan span) {
    map.contents.forEach((key, value) {
      if (key is SassIdentifier) {
        values[key.text] = value;
      } else if (key is SassString) {
        values[key.text] = value;
      } else {
        throw _exception(
            "Variable keyword argument map must have string keys.\n"
            "$key is not a string in $value.",
            span);
      }
    });
  }

  void _verifyArguments(List<Value> positional, Map<String, Value> named,
      ArgumentDeclaration arguments, FileSpan span) {
    for (var i = 0; i < arguments.arguments.length; i++) {
      var argument = arguments.arguments[i];
      if (i < positional.length) {
        if (named.containsKey(argument.name)) {
          throw _exception(
              "Argument \$${argument.name} was passed both by position and by "
              "name.",
              span);
        }
      } else if (argument.defaultValue == null &&
          !named.containsKey(argument.name)) {
        throw _exception("Missing argument \$${argument.name}.", span);
      }
    }

    if (arguments.restArgument != null) return;

    if (positional.length > arguments.arguments.length) {
      throw _exception(
          "Only ${arguments.arguments.length} "
          "${pluralize('argument', arguments.arguments.length)} allowed, "
          "but ${positional.length} "
          "${pluralize('was', positional.length, plural: 'were')} passed.",
          span);
    }

    if (arguments.arguments.length - positional.length < named.length) {
      var unknownNames = normalizedSet()
        ..addAll(named.keys)
        ..removeAll(arguments.arguments.map((argument) => argument.name));
      throw _exception(
          "No ${pluralize('argument', unknownNames.length)} named "
          "${toSentence(unknownNames.map((name) => "\$$name"), 'or')}.",
          span);
    }
  }

  Value visitSelectorExpression(SelectorExpression node) {
    if (_selector == null) return sassNull;
    return _selector.value.asSassList;
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

  CssValue<String> _interpolationToValue(Interpolation interpolation,
      {bool trim: false}) {
    var result = _performInterpolation(interpolation);
    return new CssValue(trim ? result.trim() : result, interpolation.span);
  }

  String _performInterpolation(Interpolation interpolation) {
    return interpolation.contents.map((value) {
      if (value is String) return value;
      var result = (value as Expression).accept(this);
      return result is SassString ? result.text : result;
    }).join();
  }

  CssValue<Value> _performExpression(Expression expression) =>
      new CssValue(expression.accept(this), expression.span);

  /*=T*/ _withParent/*<S extends CssParentNode, T>*/(
      /*=S*/ node,
      /*=T*/ callback(),
      {bool through(CssNode node)}) {
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
    _parent = oldParent;

    return result;
  }

  /*=T*/ _withSelector/*<T>*/(
      CssValue<SelectorList> selector,
      /*=T*/ callback()) {
    var oldSelector = _selector;
    _selector = selector;
    var result = callback();
    _selector = oldSelector;
    return result;
  }

  /*=T*/ _withMediaQueries/*<T>*/(
      List<CssMediaQuery> queries,
      /*=T*/ callback()) {
    var oldMediaQueries = _mediaQueries;
    _mediaQueries = queries;
    var result = callback();
    _mediaQueries = oldMediaQueries;
    return result;
  }

  /*=T*/ _withStackFrame/*<T>*/(
      String member, FileSpan span, /*=T*/ callback()) {
    _stack.add(_stackFrame(span));
    var oldMember = _member;
    _member = member;
    var result = callback();
    _member = oldMember;
    _stack.removeLast();
    return result;
  }

  Frame _stackFrame(FileSpan span) => new Frame(
      span.sourceUrl, span.start.line + 1, span.start.column + 1, _member);

  Trace _stackTrace(FileSpan span) {
    var frames = _stack.toList()..add(_stackFrame(span));
    return new Trace(frames.reversed);
  }

  SassRuntimeException _exception(String message, FileSpan span) =>
      new SassRuntimeException(message, span, _stackTrace(span));

  /*=T*/ _addExceptionSpan/*<T>*/(/*=T*/ callback(), FileSpan span) {
    try {
      return callback();
    } on InternalException catch (error) {
      throw _exception(error.message, span);
    }
  }
}
