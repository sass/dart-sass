// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../callable.dart';
import '../environment.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../io.dart';
import '../parse/keyframe_selector.dart';
import '../utils.dart';
import '../value.dart';
import 'interface/statement.dart';
import 'interface/expression.dart';

/// A function that takes a callback with no arguments.
typedef _ScopeCallback(callback());

/// Converts [stylesheet] to a plain CSS tree.
///
/// If [loadPaths] is passed, it's used to search for Sass files being imported.
/// Earlier paths will be preferred.
///
/// If [environment] is passed, it's used as the lexical environment when
/// evaluating [stylesheet]. It should only contain global definitions.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// Throws a [SassRuntimeException] if evaluation fails.
CssStylesheet evaluate(Stylesheet stylesheet,
        {Iterable<String> loadPaths,
        Environment environment,
        bool color: false}) =>
    new _PerformVisitor(
            loadPaths: loadPaths, environment: environment, color: color)
        .run(stylesheet);

/// A visitor that executes Sass code to produce a CSS tree.
class _PerformVisitor
    implements StatementVisitor<Value>, ExpressionVisitor<Value> {
  /// The paths to search for Sass files being imported.
  final List<String> _loadPaths;

  /// Whether to use terminal colors in warnings.
  final bool _color;

  /// The current lexical environment.
  Environment _environment;

  /// The current selector, if any.
  CssValue<SelectorList> _selector;

  /// The value of [_selector] outside an `@at-root` statement that excludes
  /// style rules.
  ///
  /// This is separate from [_selector] because `&` can see it but parent
  /// resolution cannot.
  CssValue<SelectorList> _selectorOutsideAtRoot;

  /// The current media queries, if any.
  List<CssMediaQuery> _mediaQueries;

  /// The root stylesheet node.
  CssStylesheet _root;

  /// The current parent node in the output CSS tree.
  CssParentNode _parent;

  /// The name of the current declaration parent.
  String _declarationName;

  /// The human-readable name of the current stack frame.
  var _member = "root stylesheet";

  /// The span for the innermost callable that's been invoked.
  ///
  /// This is used to provide `call()` with a span.
  FileSpan _callableSpan;

  /// Whether we're currently building the output of an unknown at rule.
  var _inUnknownAtRule = false;

  /// Whether we're currently building the output of a `@keyframes` rule.
  var _inKeyframes = false;

  /// The first index in [_root.children] after the initial block of CSS
  /// imports.
  var _endOfImports = 0;

  /// Plain-CSS imports that didn't appear in the initial block of CSS imports.
  ///
  /// These are added to the initial CSS import block by [visitStylesheet] after
  /// the stylesheet has been fully performed.
  var _outOfOrderImports = <CssImport>[];

  /// The resolved URLs for each [DynamicImport] that's been seen so far.
  ///
  /// This is cached in case the same file is imported multiple times, and thus
  /// its imports need to be resolved multiple times.
  final _importPaths = <DynamicImport, String>{};

  /// The parsed stylesheets for each resolved import URL.
  ///
  /// This is separate from [_importPaths] because multiple `@import` rules may
  /// import the same stylesheet, and we don't want to parse the same stylesheet
  /// multiple times.
  final _importedFiles = <String, Stylesheet>{};

  /// The extender that handles extensions for this perform run.
  final _extender = new Extender();

  /// The dynamic call stack representing function invocations, mixin
  /// invocations, and imports surrounding the current context.
  final _stack = <Frame>[];

  _PerformVisitor(
      {Iterable<String> loadPaths, Environment environment, bool color: false})
      : _loadPaths = loadPaths == null ? const [] : new List.from(loadPaths),
        _environment = environment ?? new Environment(),
        _color = color {
    _environment.defineFunction("call", r"$function, $args...", (arguments) {
      var function = arguments[0];
      var args = arguments[1] as SassArgumentList;

      var invocation = new ArgumentInvocation([], {}, _callableSpan,
          rest: new ValueExpression(args));

      if (function is SassString) {
        warn(
            "DEPRECATION WARNING: Passing a string to call() is deprecated and "
            "will be illegal\n"
            "in Sass 4.0. Use call(get-function($function)) instead.",
            _callableSpan,
            color: _color);

        var expression = new FunctionExpression(
            new Interpolation([function.text], _callableSpan), invocation);
        return expression.accept(this);
      }

      return _runFunctionCallable(invocation,
          function.assertFunction("function").callable, _callableSpan);
    });
  }

  CssStylesheet run(Stylesheet node) {
    visitStylesheet(node);
    return _root;
  }

  // ## Statements

  Value visitStylesheet(Stylesheet node) {
    _root = new CssStylesheet(node.span);
    _parent = _root;
    for (var child in node.children) {
      child.accept(this);
    }

    if (_outOfOrderImports.isNotEmpty) {
      _root.modifyChildren((children) {
        children.insertAll(_endOfImports, _outOfOrderImports);
      });
    }

    _extender.finalize();
    return null;
  }

  Value visitAtRootRule(AtRootRule node) {
    var query = node.query == null
        ? AtRootQuery.defaultQuery
        : new AtRootQuery.parse(_performInterpolation(node.query));

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
      return null;
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
    _scopeForAtRoot(innerCopy ?? root, query, included)(() {
      for (var child in node.children) {
        child.accept(this);
      }
    });

    return null;
  }

  /// Destructively trims a trailing sublist that matches the current list of
  /// parents from [nodes].
  ///
  /// [nodes] should be a list of parents included by an `@at-root` rule, from
  /// innermost to outermost. If it contains a trailing sublist that's
  /// contiguous—meaning that each node is a direct parent of the node before
  /// it—and whose final node is a direct child of [_root], this removes that
  /// sublist and returns the innermost removed parent.
  ///
  /// Otherwise, this leaves [nodes] as-is and returns [_root].
  CssParentNode _trimIncluded(List<CssParentNode> nodes) {
    if (nodes.isEmpty) return _root;

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

  /// Returns a [_ScopeCallback] for [query].
  ///
  /// This returns a callback that adjusts various instance variables for its
  /// duration, based on which rules are excluded by [query]. It always assigns
  /// [_parent] to [newParent].
  _ScopeCallback _scopeForAtRoot(CssParentNode newParent, AtRootQuery query,
      List<CssParentNode> included) {
    var scope = (callback()) {
      // We can't use [_withParent] here because it'll add the node to the tree
      // in the wrong place.
      var oldParent = _parent;
      _parent = newParent;
      _environment.scope(callback);
      _parent = oldParent;
    };

    if (query.excludesStyleRules) {
      var innerScope = scope;
      scope = (callback) {
        var oldSelectorOutsideAtRoot = _selectorOutsideAtRoot;
        _selectorOutsideAtRoot = _selector ?? _selectorOutsideAtRoot;
        _withSelector(null, () => innerScope(callback));
        _selectorOutsideAtRoot = oldSelectorOutsideAtRoot;
      };
    }

    if (query.excludesMedia) {
      var innerScope = scope;
      scope = (callback) => _withMediaQueries(null, () => innerScope(callback));
    }

    if (_inKeyframes && query.excludesName('keyframes')) {
      var innerScope = scope;
      scope = (callback) {
        var wasInKeyframes = _inKeyframes;
        _inKeyframes = false;
        innerScope(callback);
        _inKeyframes = wasInKeyframes;
      };
    }

    if (_inUnknownAtRule && !included.any((parent) => parent is CssAtRule)) {
      var innerScope = scope;
      scope = (callback) {
        var wasInUnknownAtRule = _inUnknownAtRule;
        _inUnknownAtRule = false;
        innerScope(callback);
        _inUnknownAtRule = wasInUnknownAtRule;
      };
    }

    return scope;
  }

  Value visitComment(Comment node) {
    if (node.isSilent) return null;

    // Comments are allowed to appear between CSS imports.
    if (_parent == _root && _endOfImports == _root.children.length) {
      _endOfImports++;
    }

    _parent.addChild(new CssComment(node.text, node.span));
    return null;
  }

  Value visitContentRule(ContentRule node) {
    var block = _environment.contentBlock;
    if (block == null) return null;

    _withStackFrame("@content", node.span, () {
      _withEnvironment(_environment.contentEnvironment, () {
        for (var statement in block) {
          statement.accept(this);
        }
      });
    });

    return null;
  }

  Value visitDebugRule(DebugRule node) {
    var start = node.span.start;
    var value = node.expression.accept(this);
    stderr.writeln("${p.prettyUri(start.sourceUrl)}:${start.line + 1} DEBUG: "
        "${value is SassString ? value.text : value}");
    return null;
  }

  Value visitDeclaration(Declaration node) {
    if (_selector == null && !_inUnknownAtRule && !_inKeyframes) {
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
        (!cssValue.value.isBlank || _isEmptyList(cssValue.value))) {
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

    return null;
  }

  /// Returns whether [value] is an empty [SassList].
  bool _isEmptyList(Value value) => value is SassList && value.contents.isEmpty;

  Value visitEachRule(EachRule node) {
    var list = node.list.accept(this);
    var setVariables = node.variables.length == 1
        ? (Value value) =>
            _environment.setLocalVariable(node.variables.first, value)
        : (Value value) => _setMultipleVariables(node.variables, value);
    return _environment.scope(() {
      return _handleReturn/*<Value>*/(list.asList, (element) {
        setVariables(element);
        return _handleReturn/*<Statement>*/(
            node.children, (child) => child.accept(this));
      });
    }, semiGlobal: true);
  }

  /// Destructures [value] and assigns it to [variables], as in an `@each`
  /// statement.
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

  Value visitErrorRule(ErrorRule node) {
    throw _exception(node.expression.accept(this).toString(), node.span);
  }

  Value visitExtendRule(ExtendRule node) {
    if (_selector == null || _declarationName != null) {
      throw _exception(
          "@extend may only be used within style rules.", node.span);
    }

    var targetText = _interpolationToValue(node.selector);

    var target = _adjustParseError(
        targetText.span,
        () => new SimpleSelector.parse(targetText.value.trim(),
            allowParent: false));
    _extender.addExtension(_selector.value, target, node);
    return null;
  }

  Value visitAtRule(AtRule node) {
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
      return null;
    }

    var wasInKeyframes = _inKeyframes;
    var wasInUnknownAtRule = _inUnknownAtRule;
    if (node.normalizedName == 'keyframes') {
      _inKeyframes = true;
    } else {
      _inUnknownAtRule = true;
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

    _inUnknownAtRule = wasInUnknownAtRule;
    _inKeyframes = wasInKeyframes;
    return null;
  }

  Value visitForRule(ForRule node) {
    var from = _addExceptionSpan(node.from.span,
        () => node.from.accept(this).assertNumber().assertInt());
    var to = _addExceptionSpan(
        node.to.span, () => node.to.accept(this).assertNumber().assertInt());

    // TODO: coerce units
    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return null;

    return _environment.scope(() {
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(node.variable, new SassNumber(i));
        var result = _handleReturn/*<Statement>*/(
            node.children, (child) => child.accept(this));
        if (result != null) return result;
      }
      return null;
    }, semiGlobal: true);
  }

  Value visitFunctionRule(FunctionRule node) {
    _environment
        .setFunction(new UserDefinedCallable(node, _environment.closure()));
    return null;
  }

  Value visitIfRule(IfRule node) {
    var clause = node.clauses
            .firstWhere((pair) => pair.item1.accept(this).isTruthy,
                orElse: () => null)
            ?.item2 ??
        node.lastClause;
    if (clause == null) return null;

    return _environment.scope(
        () =>
            _handleReturn/*<Statement>*/(clause, (child) => child.accept(this)),
        semiGlobal: true);
  }

  Value visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is DynamicImport) {
        _visitDynamicImport(import);
      } else {
        _visitStaticImport(import as StaticImport);
      }
    }
    return null;
  }

  /// Adds the stylesheet imported by [import] to the current document.
  void _visitDynamicImport(DynamicImport import) {
    var stylesheet = _loadImport(import);
    _withStackFrame("@import", import.span, () {
      _withEnvironment(_environment.global(), () {
        for (var statement in stylesheet.children) {
          statement.accept(this);
        }
      });
    });
  }

  /// Loads the [Stylesheet] imported by [import], or throws a
  /// [SassRuntimeException] if loading fails.
  Stylesheet _loadImport(DynamicImport import) {
    var path = _importPaths.putIfAbsent(import, () {
      var path = p.fromUri(import.url);
      var extension = p.extension(path);
      var tryPath = extension == '.sass' || extension == '.scss'
          ? _tryImportPath
          : _tryImportPathWithExtensions;

      var base = p.dirname(p.fromUri(import.span.file.url));
      var resolved = tryPath(p.join(base, path));
      if (resolved != null) return resolved;

      for (var loadPath in _loadPaths) {
        var resolved = tryPath(p.join(loadPath, path));
        if (resolved != null) return resolved;
      }
    });

    if (path == null) {
      throw _exception("Can't find file to import.", import.span);
    }

    return _importedFiles.putIfAbsent(path, () {
      var contents = readFile(path);
      var url = p.toUri(path);
      return p.extension(path) == '.sass'
          ? new Stylesheet.parseSass(contents, url: url, color: _color)
          : new Stylesheet.parseScss(contents, url: url, color: _color);
    });
  }

  /// Like [_tryImportPath], but checks both `.sass` and `.scss` extensions.
  String _tryImportPathWithExtensions(String path) =>
      _tryImportPath(path + '.sass') ?? _tryImportPath(path + '.scss');

  /// If a file exists at [path], or a partial with the same name exists,
  /// returns the resolved path.
  ///
  /// Otherwise, returns `null`.
  String _tryImportPath(String path) {
    var partial = p.join(p.dirname(path), "_${p.basename(path)}");
    if (fileExists(partial)) return partial;
    if (fileExists(path)) return path;
    return null;
  }

  /// Adds a CSS import for [import].
  void _visitStaticImport(StaticImport import) {
    var url = _interpolationToValue(import.url);
    var supports = import.supports;
    var resolvedSupports = supports is SupportsDeclaration
        ? "${supports.name.accept(this).toCssString()}: "
            "${supports.value.accept(this).toCssString()})"
        : (supports == null ? null : _visitSupportsCondition(supports));
    var mediaQuery =
        import.media == null ? null : _visitMediaQueries(import.media);

    var node = new CssImport(url, import.span,
        supports: resolvedSupports == null
            ? null
            : new CssValue(resolvedSupports, import.supports.span),
        media: mediaQuery);

    if (_parent != _root) {
      _parent.addChild(node);
    } else if (_endOfImports == _root.children.length) {
      _root.addChild(node);
      _endOfImports++;
    } else {
      _outOfOrderImports.add(node);
    }
    return null;
  }

  Value visitIncludeRule(IncludeRule node) {
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
      _runUserDefinedCallable(node.arguments, mixin, node.span, callback);
    } else {
      var environment = _environment.closure();
      _runUserDefinedCallable(node.arguments, mixin, node.span, () {
        _environment.withContent(node.children, environment, callback);
      });
    }

    return null;
  }

  Value visitMixinRule(MixinRule node) {
    _environment
        .setMixin(new UserDefinedCallable(node, _environment.closure()));
    return null;
  }

  Value visitMediaRule(MediaRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var queries = _visitMediaQueries(node.query);
    if (_mediaQueries != null) {
      queries = _mergeMediaQueries(_mediaQueries, queries);
      if (queries.isEmpty) return null;
    }

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

    return null;
  }

  /// Evaluates [interpolation] and parses the result as a list of media
  /// queries.
  List<CssMediaQuery> _visitMediaQueries(Interpolation interpolation) =>
      _adjustParseError(interpolation.span,
          () => CssMediaQuery.parseList(_performInterpolation(interpolation)));

  /// Returns a list of queries that selects for platforms that match both
  /// [queries1] and [queries2].
  List<CssMediaQuery> _mergeMediaQueries(
      Iterable<CssMediaQuery> queries1, Iterable<CssMediaQuery> queries2) {
    return new List.unmodifiable(queries1.expand/*<CssMediaQuery>*/((query1) {
      return queries2.map((query2) => query1.merge(query2));
    }).where((query) => query != null));
  }

  Value visitReturnRule(ReturnRule node) => node.expression.accept(this);

  Value visitStyleRule(StyleRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var selectorText = _interpolationToValue(node.selector, trim: true);
    if (_inKeyframes) {
      var parsedSelector = _adjustParseError(node.selector.span,
          () => new KeyframeSelectorParser(selectorText.value).parse());
      var rule = new CssKeyframeBlock(
          new CssValue(
              new List.unmodifiable(parsedSelector), node.selector.span),
          node.span);
      _withParent(rule, () {
        for (var child in node.children) {
          child.accept(this);
        }
      }, through: (node) => node is CssStyleRule);
      return null;
    }

    var parsedSelector = _adjustParseError(
        node.selector.span, () => new SelectorList.parse(selectorText.value));
    parsedSelector = _addExceptionSpan(node.selector.span,
        () => parsedSelector.resolveParentSelectors(_selector?.value));

    var selector =
        new CssValue<SelectorList>(parsedSelector, node.selector.span);

    var rule = _extender.addSelector(selector, node.span);
    _withParent(rule, () {
      _withSelector(rule.selector, () {
        for (var child in node.children) {
          child.accept(this);
        }
      });
    }, through: (node) => node is CssStyleRule);

    if (_selector == null) {
      var lastChild = _parent.children.last;
      lastChild.isGroupEnd = true;
    }

    return null;
  }

  Value visitSupportsRule(SupportsRule node) {
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

    return null;
  }

  /// Evaluates [condition] and converts it to a plain CSS string.
  String _visitSupportsCondition(SupportsCondition condition) {
    if (condition is SupportsOperation) {
      return "${_parenthesize(condition.left, condition.operator)} "
          "${condition.operator} "
          "${_parenthesize(condition.right, condition.operator)}";
    } else if (condition is SupportsNegation) {
      return "not ${_parenthesize(condition.condition)}";
    } else if (condition is SupportsInterpolation) {
      return condition.expression.accept(this).toCssString(quote: false);
    } else if (condition is SupportsDeclaration) {
      return "(${condition.name.accept(this).toCssString()}: "
          "${condition.value.accept(this).toCssString()})";
    } else {
      return null;
    }
  }

  /// Evlauates [condition] and converts it to a plain CSS string, with
  /// parentheses if necessary.
  ///
  /// If [operator] is passed, it's the operator for the surrounding
  /// [SupportsOperation], and is used to determine whether parentheses are
  /// necessary if [condition] is also a [SupportsOperation].
  String _parenthesize(SupportsCondition condition, [String operator]) {
    if ((condition is SupportsNegation) ||
        (condition is SupportsOperation &&
            (operator == null || operator != condition.operator))) {
      return "(${_visitSupportsCondition(condition)})";
    } else {
      return _visitSupportsCondition(condition);
    }
  }

  Value visitVariableDeclaration(VariableDeclaration node) {
    if (node.isGuarded) {
      var value = _environment.getVariable(node.name);
      if (value != null && value != sassNull) return null;
    }

    _environment.setVariable(
        node.name, node.expression.accept(this).withoutSlash(),
        global: node.isGlobal);
    return null;
  }

  Value visitWarnRule(WarnRule node) {
    _addExceptionSpan(node.span, () {
      var value = node.expression.accept(this);
      var string = value is SassString ? value.text : value.toCssString();
      stderr.writeln("WARNING: $string");
    });

    for (var line in _stackTrace(node.span).toString().split("\n")) {
      stderr.writeln("         $line");
    }

    return null;
  }

  Value visitWhileRule(WhileRule node) {
    return _environment.scope(() {
      while (node.condition.accept(this).isTruthy) {
        var result = _handleReturn/*<Statement>*/(
            node.children, (child) => child.accept(this));
        if (result != null) return result;
      }
      return null;
    }, semiGlobal: true);
  }

  // ## Expressions

  Value visitBinaryOperationExpression(BinaryOperationExpression node) {
    return _addExceptionSpan(node.span, () {
      var left = node.left.accept(this);
      var right = node.right.accept(this);
      switch (node.operator) {
        case BinaryOperator.singleEquals:
          return left.singleEquals(right);
        case BinaryOperator.or:
          return left.or(right);
        case BinaryOperator.and:
          return left.and(right);
        case BinaryOperator.equals:
          return new SassBoolean(left == right);
        case BinaryOperator.notEquals:
          return new SassBoolean(left != right);
        case BinaryOperator.greaterThan:
          return left.greaterThan(right);
        case BinaryOperator.greaterThanOrEquals:
          return left.greaterThanOrEquals(right);
        case BinaryOperator.lessThan:
          return left.lessThan(right);
        case BinaryOperator.lessThanOrEquals:
          return left.lessThanOrEquals(right);
        case BinaryOperator.plus:
          return left.plus(right);
        case BinaryOperator.minus:
          return left.minus(right);
        case BinaryOperator.times:
          return left.times(right);
        case BinaryOperator.dividedBy:
          var result = left.dividedBy(right);
          if (node.allowsSlash && left is SassNumber && right is SassNumber) {
            var leftSlash = left.asSlash ?? left.toCssString();
            var rightSlash = right.asSlash ?? right.toCssString();
            return (result as SassNumber).withSlash("$leftSlash/$rightSlash");
          } else {
            return result;
          }
          break;
        case BinaryOperator.modulo:
          return left.modulo(right);
        default:
          return null;
      }
    });
  }

  Value visitValueExpression(ValueExpression node) => node.value;

  Value visitVariableExpression(VariableExpression node) {
    var result = _environment.getVariable(node.name);
    if (result != null) return result;
    throw _exception("Undefined variable.", node.span);
  }

  Value visitUnaryOperationExpression(UnaryOperationExpression node) {
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

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      new SassBoolean(node.value);

  Value visitIfExpression(IfExpression node) {
    var pair = _evaluateMacroArguments(node);
    var positional = pair.item1;
    var named = pair.item2;

    _verifyArguments(
        positional.length, named, IfExpression.declaration, node.span);

    var condition = positional.length > 0 ? positional[0] : named["condition"];
    var ifTrue = positional.length > 1 ? positional[1] : named["if-true"];
    var ifFalse = positional.length > 2 ? positional[2] : named["if-false"];

    return (condition.accept(this).isTruthy ? ifTrue : ifFalse).accept(this);
  }

  SassNull visitNullExpression(NullExpression node) => sassNull;

  SassNumber visitNumberExpression(NumberExpression node) =>
      new SassNumber(node.value, node.unit);

  SassColor visitColorExpression(ColorExpression node) => node.value;

  SassList visitListExpression(ListExpression node) => new SassList(
      node.contents.map((expression) => expression.accept(this)),
      node.separator,
      brackets: node.hasBrackets);

  SassMap visitMapExpression(MapExpression node) {
    var map = <Value, Value>{};
    for (var pair in node.pairs) {
      var keyValue = pair.item1.accept(this);
      var valueValue = pair.item2.accept(this);
      if (map.containsKey(keyValue)) {
        throw _exception('Duplicate key.', pair.item1.span);
      }
      map[keyValue] = valueValue;
    }
    return new SassMap(map);
  }

  Value visitFunctionExpression(FunctionExpression node) {
    var plainName = node.name.asPlain;
    var function =
        (plainName == null ? null : _environment.getFunction(plainName)) ??
            new PlainCssCallable(_performInterpolation(node.name));

    return _runFunctionCallable(node.arguments, function, node.span);
  }

  /// Evaluates the arguments in [arguments] as applied to [callable], and
  /// invokes [run] in a scope with those arguments defined.
  Value _runUserDefinedCallable(ArgumentInvocation arguments,
      UserDefinedCallable callable, FileSpan span, Value run()) {
    var triple = _evaluateArguments(arguments, span);
    var positional = triple.item1;
    var named = triple.item2;
    var separator = triple.item3;

    return _withStackFrame(callable.name + "()", span, () {
      return _withEnvironment(callable.environment, () {
        return _environment.scope(() {
          _verifyArguments(
              positional.length, named, callable.declaration.arguments, span);

          // TODO: if we get here and there are no rest params involved, mark
          // the callable as fast-path and don't do error checking or extra
          // allocations for future calls.
          var declaredArguments = callable.declaration.arguments.arguments;
          var minLength = math.min(positional.length, declaredArguments.length);
          for (var i = 0; i < minLength; i++) {
            _environment.setLocalVariable(
                declaredArguments[i].name, positional[i]);
          }

          for (var i = positional.length; i < declaredArguments.length; i++) {
            var argument = declaredArguments[i];
            _environment.setLocalVariable(
                argument.name,
                named.remove(argument.name) ??
                    argument.defaultValue?.accept(this));
          }

          SassArgumentList argumentList;
          if (callable.declaration.arguments.restArgument != null) {
            var rest = positional.length > declaredArguments.length
                ? positional.sublist(declaredArguments.length)
                : const <Value>[];
            argumentList = new SassArgumentList(
                rest,
                named,
                separator == ListSeparator.undecided
                    ? ListSeparator.comma
                    : separator);
            _environment.setLocalVariable(
                callable.declaration.arguments.restArgument, argumentList);
          }

          var result = run();

          if (argumentList == null) return result;
          if (named.isEmpty) return result;
          if (argumentList.wereKeywordsAccessed) return result;
          throw _exception(
              "No ${pluralize('argument', named.keys.length)} named "
              "${toSentence(named.keys.map((name) => "\$$name"), 'or')}.",
              span);
        });
      });
    });
  }

  /// Evaluates [arguments] as applied to [callable].
  Value _runFunctionCallable(
      ArgumentInvocation arguments, Callable callable, FileSpan span) {
    if (callable is BuiltInCallable) {
      return _runBuiltInCallable(arguments, callable, span).withoutSlash();
    } else if (callable is UserDefinedCallable) {
      return _runUserDefinedCallable(arguments, callable, span, () {
        for (var statement in callable.declaration.children) {
          var returnValue = statement.accept(this);
          if (returnValue is Value) return returnValue;
        }

        throw _exception(
            "Function finished without @return.", callable.declaration.span);
      }).withoutSlash();
    } else if (callable is PlainCssCallable) {
      if (arguments.named.isNotEmpty || arguments.keywordRest != null) {
        throw _exception(
            "Plain CSS functions don't support keyword arguments.", span);
      }

      var argumentValues = arguments.positional
          .map((expression) => expression.accept(this))
          .toList();
      // TODO: if rest is an arglist that has keywords, error out.
      var rest = arguments.rest?.accept(this);
      if (rest != null) argumentValues.add(rest);
      return new SassString("${callable.name}(" +
          argumentValues.map((argument) => argument.toCssString()).join(', ') +
          ")");
    } else {
      return null;
    }
  }

  /// Evaluates [invocation] as applied to [callable], and invokes [callable]'s
  /// body.
  Value _runBuiltInCallable(
      ArgumentInvocation arguments, BuiltInCallable callable, FileSpan span) {
    var triple = _evaluateArguments(arguments, span);
    var positional = triple.item1;
    var named = triple.item2;
    var namedSet = named;
    var separator = triple.item3;

    var oldCallableSpan = _callableSpan;
    _callableSpan = span;
    int overloadIndex;
    for (var i = 0; i < callable.overloads.length - 1; i++) {
      try {
        _verifyArguments(
            positional.length, namedSet, callable.overloads[i], span);
        overloadIndex = i;
        break;
      } on SassRuntimeException catch (_) {
        continue;
      }
    }
    if (overloadIndex == null) {
      _verifyArguments(
          positional.length, namedSet, callable.overloads.last, span);
      overloadIndex = callable.overloads.length - 1;
    }

    var overload = callable.overloads[overloadIndex];
    var callback = callable.callbacks[overloadIndex];
    var declaredArguments = overload.arguments;
    for (var i = positional.length; i < declaredArguments.length; i++) {
      var argument = declaredArguments[i];
      positional.add(
          named.remove(argument.name) ?? argument.defaultValue?.accept(this));
    }

    SassArgumentList argumentList;
    if (overload.restArgument != null) {
      var rest = const <Value>[];
      if (positional.length > declaredArguments.length) {
        rest = positional.sublist(declaredArguments.length);
        positional.removeRange(declaredArguments.length, positional.length);
      }

      argumentList = new SassArgumentList(
          rest,
          named,
          separator == ListSeparator.undecided
              ? ListSeparator.comma
              : separator);
      positional.add(argumentList);
    }

    var result = _addExceptionSpan(span, () => callback(positional));
    _callableSpan = oldCallableSpan;

    if (argumentList == null) return result;
    if (named.isEmpty) return result;
    if (argumentList.wereKeywordsAccessed) return result;
    throw _exception(
        "No ${pluralize('argument', named.keys.length)} named "
        "${toSentence(named.keys.map((name) => "\$$name"), 'or')}.",
        span);
  }

  /// Evaluates the arguments in [arguments] and returns the positional and
  /// named arguments, as well as the [ListSeparator] for the rest argument
  /// list, if any.
  Tuple3<List<Value>, Map<String, Value>, ListSeparator> _evaluateArguments(
      ArgumentInvocation arguments, FileSpan span) {
    var positional = arguments.positional
        .map((expression) => expression.accept(this))
        .toList();
    var named = normalizedMapMap/*<String, Expression, Value>*/(arguments.named,
        value: (_, expression) => expression.accept(this));

    if (arguments.rest == null) {
      return new Tuple3(positional, named, ListSeparator.undecided);
    }

    var rest = arguments.rest.accept(this);
    var separator = ListSeparator.undecided;
    if (rest is SassMap) {
      _addRestMap(named, rest, span);
    } else if (rest is SassList) {
      positional.addAll(rest.asList);
      separator = rest.separator;
      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = value;
        });
      }
    } else {
      positional.add(rest);
    }

    if (arguments.keywordRest == null) {
      return new Tuple3(positional, named, separator);
    }

    var keywordRest = arguments.keywordRest.accept(this);
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, span);
      return new Tuple3(positional, named, separator);
    } else {
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).", span);
    }
  }

  /// Evaluates the arguments in [arguments] only as much as necessary to
  /// separate out positional and named arguments.
  ///
  /// Returns the arguments as expressions so that they can be lazily evaluated
  /// for macros such as `if()`.
  Tuple2<List<Expression>, Map<String, Expression>> _evaluateMacroArguments(
      CallableInvocation invocation) {
    if (invocation.arguments.rest == null) {
      return new Tuple2(
          invocation.arguments.positional, invocation.arguments.named);
    }

    var positional = invocation.arguments.positional.toList();
    var named = normalizedMap(invocation.arguments.named);
    var rest = invocation.arguments.rest.accept(this);
    if (rest is SassMap) {
      _addRestMap(
          named, rest, invocation.span, (value) => new ValueExpression(value));
    } else if (rest is SassList) {
      positional.addAll(rest.asList.map((value) => new ValueExpression(value)));
      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = new ValueExpression(value);
        });
      }
    } else {
      positional.add(new ValueExpression(rest));
    }

    if (invocation.arguments.keywordRest == null) {
      return new Tuple2(positional, named);
    }

    var keywordRest = invocation.arguments.keywordRest.accept(this);
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, invocation.span,
          (value) => new ValueExpression(value));
      return new Tuple2(positional, named);
    } else {
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).",
          invocation.span);
    }
  }

  /// Adds the values in [map] to [values].
  ///
  /// Throws a [SassRuntimeException] associated with [span] if any [map] keys
  /// aren't strings.
  ///
  /// If [convert] is passed, that's used to convert the map values to the value
  /// type for [values]. Otherwise, the [Value]s are used as-is.
  void _addRestMap/*<T>*/(
      Map<String, Object/*=T*/ > values, SassMap map, FileSpan span,
      [/*=T*/ convert(Value value)]) {
    convert ??= (value) => value as Object/*=T*/;
    map.contents.forEach((key, value) {
      if (key is SassString) {
        values[key.text] = convert(value);
      } else {
        throw _exception(
            "Variable keyword argument map must have string keys.\n"
            "$key is not a string in $map.",
            span);
      }
    });
  }

  /// Throws a [SassRuntimeException] if [positional] and [named] aren't valid
  /// when applied to [arguments].
  void _verifyArguments(int positional, Map<String, dynamic> named,
      ArgumentDeclaration arguments, FileSpan span) {
    for (var i = 0; i < arguments.arguments.length; i++) {
      var argument = arguments.arguments[i];
      if (i < positional) {
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

    if (positional > arguments.arguments.length) {
      throw _exception(
          "Only ${arguments.arguments.length} "
          "${pluralize('argument', arguments.arguments.length)} allowed, but "
          "${positional} ${pluralize('was', positional, plural: 'were')} "
          "passed.",
          span);
    }

    if (arguments.arguments.length - positional < named.length) {
      var unknownNames = normalizedSet(named.keys)
        ..removeAll(arguments.arguments.map((argument) => argument.name));
      throw _exception(
          "No ${pluralize('argument', unknownNames.length)} named "
          "${toSentence(unknownNames.map((name) => "\$$name"), 'or')}.",
          span);
    }
  }

  Value visitSelectorExpression(SelectorExpression node) {
    var selector = _selector ?? _selectorOutsideAtRoot;
    if (selector == null) return sassNull;
    return selector.value.asSassList;
  }

  SassString visitStringExpression(StringExpression node) {
    // Don't use [performInterpolation] here because we need to get the raw text
    // from strings.
    return new SassString(
        node.text.contents.map((value) {
          if (value is String) return value;
          var result = (value as Expression).accept(this);
          return result is SassString
              ? result.text
              : result.toCssString(quote: false);
        }).join(),
        quotes: node.hasQuotes);
  }

  // ## Utilities

  /// Runs [callback] for each value in [list] until it returns a [Value].
  ///
  /// Returns the value returned by [callback], or `null` if it only ever
  /// returned `null`.
  Value _handleReturn/*<T>*/(List/*<T>*/ list, Value callback(/*=T*/ value)) {
    for (var value in list) {
      var result = callback(value);
      if (result != null) return result;
    }
    return null;
  }

  /// Runs [callback] with [environment] as the current environment.
  /*=T*/ _withEnvironment/*<T>*/(Environment environment, /*=T*/ callback()) {
    var oldEnvironment = _environment;
    _environment = environment;
    var result = callback();
    _environment = oldEnvironment;
    return result;
  }

  /// Evaluates [interpolation] and wraps the result in a [CssValue].
  ///
  /// If [trim] is `true`, removes whitespace around the result.
  CssValue<String> _interpolationToValue(Interpolation interpolation,
      {bool trim: false}) {
    var result = _performInterpolation(interpolation);
    return new CssValue(trim ? result.trim() : result, interpolation.span);
  }

  /// Evaluates [interpolation].
  String _performInterpolation(Interpolation interpolation) {
    return interpolation.contents.map((value) {
      if (value is String) return value;
      var result = (value as Expression).accept(this);
      return result.toCssString(quote: false);
    }).join();
  }

  /// Evaluates [expression] and wraps the result in a [CssValue].
  CssValue<Value> _performExpression(Expression expression) =>
      new CssValue(expression.accept(this), expression.span);

  /// Adds [node] as a child of the current parent, then runs [callback] with
  /// [node] as the current parent.
  ///
  /// If [through] is passed, [node] is added as a child of the first parent for
  /// which [through] returns `false`.
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

  /// Runs [callback] with [selector] as the current selector.
  /*=T*/ _withSelector/*<T>*/(
      CssValue<SelectorList> selector,
      /*=T*/ callback()) {
    var oldSelector = _selector;
    _selector = selector;
    var result = callback();
    _selector = oldSelector;
    return result;
  }

  /// Runs [callback] with [queries] as the current media queries.
  /*=T*/ _withMediaQueries/*<T>*/(
      List<CssMediaQuery> queries,
      /*=T*/ callback()) {
    var oldMediaQueries = _mediaQueries;
    _mediaQueries = queries;
    var result = callback();
    _mediaQueries = oldMediaQueries;
    return result;
  }

  /// Adds a frame to the stack with the given [member] name, and [span] as the
  /// site of the new frame.
  ///
  /// Runs [callback] with the new stack.
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

  /// Creates a new stack frame with location information from [span] and
  /// [_member].
  Frame _stackFrame(FileSpan span) => new Frame(
      span.sourceUrl, span.start.line + 1, span.start.column + 1, _member);

  /// Returns a stack trace at the current point.
  ///
  /// [span] is the current location, used for the bottom-most stack frame.
  Trace _stackTrace(FileSpan span) {
    var frames = _stack.toList()..add(_stackFrame(span));
    return new Trace(frames.reversed);
  }

  /// Throws a [SassRuntimeException] with the given [message] and [span].
  SassRuntimeException _exception(String message, FileSpan span) =>
      new SassRuntimeException(message, span, _stackTrace(span));

  /// Runs [callback], and adjusts any [SassFormatException] to be within [span].
  ///
  /// Specifically, this adjusts format exceptions so that the errors are
  /// reported as though the text being parsed were exactly in [span]. This may
  /// not be quite accurate if the source text contained interpolation, but
  /// it'll still produce a useful error.
  /*=T*/ _adjustParseError/*<T>*/(FileSpan span, /*=T*/ callback()) {
    try {
      return callback();
    } on SassFormatException catch (error) {
      var errorText = error.span.file.getText(0);
      var syntheticFile = span.file
          .getText(0)
          .replaceRange(span.start.offset, span.end.offset, errorText);
      var syntheticSpan = new SourceFile(syntheticFile, url: span.file.url)
          .span(span.start.offset + error.span.start.offset,
              span.start.offset + error.span.end.offset);
      throw _exception(error.message, syntheticSpan);
    }
  }

  /// Runs [callback], and converts any [SassScriptException]s it throws to
  /// [SassRuntimeException]s with [span].
  /*=T*/ _addExceptionSpan/*<T>*/(FileSpan span, /*=T*/ callback()) {
    try {
      return callback();
    } on SassScriptException catch (error) {
      throw _exception(error.message, span);
    }
  }
}
