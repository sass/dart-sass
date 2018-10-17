// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_evaluate.dart.
// See tool/synchronize.dart for details.
//
// Checksum: ce258987d3496f06c82ca1f31df4a0ac778fe326

import 'async_evaluate.dart' show EvaluateResult;
export 'async_evaluate.dart' show EvaluateResult;

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../environment.dart';
import '../import_cache.dart';
import '../callable.dart';
import '../color_names.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../importer.dart';
import '../importer/node.dart';
import '../logger.dart';
import '../parse/keyframe_selector.dart';
import '../syntax.dart';
import '../utils.dart';
import '../value.dart';
import 'interface/statement.dart';
import 'interface/expression.dart';

/// A function that takes a callback with no arguments.
typedef void _ScopeCallback(void callback());

/// Converts [stylesheet] to a plain CSS tree.
///
/// If [importCache] (or, on Node.js, [nodeImporter]) is passed, it's used to
/// resolve imports in the Sass files.
///
/// If [importer] is passed, it's used to resolve relative imports in
/// [stylesheet] relative to `stylesheet.span.sourceUrl`.
///
/// The [functions] are available as global functions when evaluating
/// [stylesheet].
///
/// The [variables] are available as global variables when evaluating
/// [stylesheet].
///
/// Warnings are emitted using [logger], or printed to standard error by
/// default.
///
/// If [sourceMap] is `true`, this will track the source locations of variable
/// declarations.
///
/// Throws a [SassRuntimeException] if evaluation fails.
EvaluateResult evaluate(Stylesheet stylesheet,
        {ImportCache importCache,
        NodeImporter nodeImporter,
        Importer importer,
        Iterable<Callable> functions,
        Map<String, Value> variables,
        Logger logger,
        bool sourceMap: false}) =>
    new _EvaluateVisitor(
            importCache: importCache,
            nodeImporter: nodeImporter,
            importer: importer,
            functions: functions,
            variables: variables,
            logger: logger,
            sourceMap: sourceMap)
        .run(stylesheet);

/// Evaluates a single [expression]
///
/// The [functions] are available as global functions when evaluating
/// [expression].
///
/// The [variables] are available as global variables when evaluating
/// [expression].
///
/// Warnings are emitted using [logger], or printed to standard error by
/// default.
///
/// Throws a [SassRuntimeException] if evaluation fails.
Value evaluateExpression(Expression expression,
        {Iterable<Callable> functions,
        Map<String, Value> variables,
        Logger logger}) =>
    expression.accept(new _EvaluateVisitor(
        functions: functions,
        variables: variables,
        logger: logger,
        sourceMap: false));

/// A visitor that executes Sass code to produce a CSS tree.
class _EvaluateVisitor
    implements StatementVisitor<Value>, ExpressionVisitor<Value> {
  /// The import cache used to import other stylesheets.
  final ImportCache _importCache;

  /// The Node Sass-compatible importer to use when loading new Sass files when
  /// compiled to Node.js.
  final NodeImporter _nodeImporter;

  /// The logger to use to print warnings.
  final Logger _logger;

  /// Whether to track source map information.
  final bool _sourceMap;

  /// The current lexical environment.
  Environment _environment;

  /// The importer that's currently being used to resolve relative imports.
  ///
  /// If this is `null`, relative imports aren't supported in the current
  /// stylesheet.
  Importer _importer;

  /// The stylesheet that's currently being evaluated.
  Stylesheet _stylesheet;

  /// The style rule that defines the current parent selector, if any.
  CssStyleRule _styleRule;

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

  /// Whether we're currently executing a function.
  var _inFunction = false;

  /// Whether we're currently building the output of an unknown at rule.
  var _inUnknownAtRule = false;

  /// Whether we're currently building the output of a style rule.
  bool get _inStyleRule => _styleRule != null && !_atRootExcludingStyleRule;

  /// Whether we're directly within an `@at-root` rule that excludes style
  /// rules.
  var _atRootExcludingStyleRule = false;

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

  /// The set that will eventually populate the JS API's
  /// `result.stats.includedFiles` field.
  ///
  /// For filesystem imports, this contains the import path. For all other
  /// imports, it contains the URL passed to the `@import`.
  final _includedFiles = new Set<String>();

  final _activeImports = new Set<Uri>();

  /// The extender that handles extensions for this perform run.
  final _extender = new Extender();

  /// The dynamic call stack representing function invocations, mixin
  /// invocations, and imports surrounding the current context.
  ///
  /// Each member is a tuple of the span where the stack trace starts and the
  /// name of the member being invoked.
  final _stack = <Tuple2<String, FileSpan>>[];

  /// Whether we're running in Node Sass-compatibility mode.
  bool get _asNodeSass => _nodeImporter != null;

  _EvaluateVisitor(
      {ImportCache importCache,
      NodeImporter nodeImporter,
      Importer importer,
      Iterable<Callable> functions,
      Map<String, Value> variables,
      Logger logger,
      bool sourceMap})
      : _importCache = importCache ?? ImportCache.none,
        _importer = importer ?? Importer.noOp,
        _nodeImporter = nodeImporter,
        _logger = logger ?? const Logger.stderr(),
        _sourceMap = sourceMap,
        _environment = new Environment(sourceMap: sourceMap) {
    _environment.setFunction(
        new BuiltInCallable("global-variable-exists", r"$name", (arguments) {
      var variable = arguments[0].assertString("name");
      return new SassBoolean(_environment.globalVariableExists(variable.text));
    }));

    _environment.setFunction(
        new BuiltInCallable("variable-exists", r"$name", (arguments) {
      var variable = arguments[0].assertString("name");
      return new SassBoolean(_environment.variableExists(variable.text));
    }));

    _environment.setFunction(
        new BuiltInCallable("function-exists", r"$name", (arguments) {
      var variable = arguments[0].assertString("name");
      return new SassBoolean(_environment.functionExists(variable.text));
    }));

    _environment
        .setFunction(new BuiltInCallable("mixin-exists", r"$name", (arguments) {
      var variable = arguments[0].assertString("name");
      return new SassBoolean(_environment.mixinExists(variable.text));
    }));

    _environment
        .setFunction(new BuiltInCallable("content-exists", "", (arguments) {
      if (!_environment.inMixin) {
        throw new SassScriptException(
            "content-exists() may only be called within a mixin.");
      }
      return new SassBoolean(_environment.contentBlock != null);
    }));

    _environment.setFunction(
        new BuiltInCallable("get-function", r"$name, $css: false", (arguments) {
      var name = arguments[0].assertString("name");
      var css = arguments[1].isTruthy;

      var callable = css
          ? new PlainCssCallable(name.text)
          : _environment.getFunction(name.text);
      if (callable != null) return new SassFunction(callable);

      throw new SassScriptException("Function not found: $name");
    }));

    _environment.setFunction(
        new BuiltInCallable("call", r"$function, $args...", (arguments) {
      var function = arguments[0];
      var args = arguments[1] as SassArgumentList;

      var invocation = new ArgumentInvocation([], {}, _callableSpan,
          rest: new ValueExpression(args, _callableSpan),
          keywordRest: args.keywords.isEmpty
              ? null
              : new ValueExpression(
                  new SassMap(mapMap(args.keywords,
                      key: (String key, Value _) =>
                          new SassString(key, quotes: false),
                      value: (String _, Value value) => value)),
                  _callableSpan));

      if (function is SassString) {
        _warn(
            "Passing a string to call() is deprecated and will be illegal\n"
            "in Sass 4.0. Use call(get-function($function)) instead.",
            _callableSpan,
            deprecation: true);

        var expression = new FunctionExpression(
            new Interpolation([function.text], _callableSpan), invocation);
        return expression.accept(this);
      }

      var callable = function.assertFunction("function").callable;
      if (callable is Callable) {
        return _runFunctionCallable(invocation, callable, _callableSpan);
      } else {
        throw new SassScriptException(
            "The function ${callable.name} is asynchronous.\n"
            "This is probably caused by a bug in a Sass plugin.");
      }
    }));

    for (var function in functions ?? const <Callable>[]) {
      _environment.setFunction(function);
    }

    for (var name in variables?.keys ?? const <String>[]) {
      _environment.setVariable(name, variables[name], null, global: true);
    }
  }

  EvaluateResult run(Stylesheet node) {
    var url = node.span?.sourceUrl;
    if (url != null) {
      if (_asNodeSass) {
        if (url.scheme == 'file') {
          _includedFiles.add(p.fromUri(url));
        } else if (url.toString() != 'stdin') {
          _includedFiles.add(url.toString());
        }
      }
    }

    visitStylesheet(node);

    return new EvaluateResult(_root, _includedFiles);
  }

  // ## Statements

  Value visitStylesheet(Stylesheet node) {
    _stylesheet = node;
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
    var query = AtRootQuery.defaultQuery;
    if (node.query != null) {
      var resolved = _performInterpolation(node.query, warnForColor: true);
      query = _adjustParseError(node.query.span,
          () => new AtRootQuery.parse(resolved, logger: _logger));
    }

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
      _environment.scope(() {
        for (var child in node.children) {
          child.accept(this);
        }
      }, when: node.hasDeclarations);
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
    _scopeForAtRoot(node, innerCopy ?? root, query, included)(() {
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
  _ScopeCallback _scopeForAtRoot(AtRootRule node, CssParentNode newParent,
      AtRootQuery query, List<CssParentNode> included) {
    var scope = (void callback()) {
      // We can't use [_withParent] here because it'll add the node to the tree
      // in the wrong place.
      var oldParent = _parent;
      _parent = newParent;
      _environment.scope(callback, when: node.hasDeclarations);
      _parent = oldParent;
    };

    if (query.excludesStyleRules) {
      var innerScope = scope;
      scope = (callback) {
        var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
        _atRootExcludingStyleRule = true;
        innerScope(callback);
        _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;
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

  Value visitContentRule(ContentRule node) {
    var block = _environment.contentBlock;
    if (block == null) return null;

    _withStackFrame("@content", node.span, () {
      // Add an extra closure() call so that modifications to the environment
      // don't affect the underlying environment closure.
      _withEnvironment(_environment.contentEnvironment.closure(), () {
        for (var statement in block) {
          statement.accept(this);
        }
      });
    });

    return null;
  }

  Value visitDebugRule(DebugRule node) {
    var value = node.expression.accept(this);
    _logger.debug(
        value is SassString ? value.text : value.toString(), node.span);
    return null;
  }

  Value visitDeclaration(Declaration node) {
    if (!_inStyleRule && !_inUnknownAtRule && !_inKeyframes) {
      throw _exception(
          "Declarations may only be used within style rules.", node.span);
    }

    var name = _interpolationToValue(node.name, warnForColor: true);
    if (_declarationName != null) {
      name = new CssValue("$_declarationName-${name.value}", name.span);
    }
    var cssValue = node.value == null
        ? null
        : new CssValue(node.value.accept(this), node.value.span);

    // If the value is an empty list, preserve it, because converting it to CSS
    // will throw an error that we want the user to see.
    if (cssValue != null &&
        (!cssValue.value.isBlank || _isEmptyList(cssValue.value))) {
      _parent.addChild(new CssDeclaration(name, cssValue, node.span,
          valueSpanForMap: _expressionSpan(node.value)));
    } else if (name.value.startsWith('--')) {
      throw _exception(
          "Custom property values may not be empty.", node.value.span);
    }

    if (node.children != null) {
      var oldDeclarationName = _declarationName;
      _declarationName = name.value;
      _environment.scope(() {
        for (var child in node.children) {
          child.accept(this);
        }
      }, when: node.hasDeclarations);
      _declarationName = oldDeclarationName;
    }

    return null;
  }

  /// Returns whether [value] is an empty list.
  bool _isEmptyList(Value value) => value.asList.isEmpty;

  Value visitEachRule(EachRule node) {
    var list = node.list.accept(this);
    var span = _expressionSpan(node.list);
    var setVariables = node.variables.length == 1
        ? (Value value) => _environment.setLocalVariable(
            node.variables.first, value.withoutSlash(), span)
        : (Value value) => _setMultipleVariables(node.variables, value, span);
    return _environment.scope(() {
      return _handleReturn<Value>(list.asList, (element) {
        setVariables(element);
        return _handleReturn<Statement>(
            node.children, (child) => child.accept(this));
      });
    }, semiGlobal: true);
  }

  /// Destructures [value] and assigns it to [variables], as in an `@each`
  /// statement.
  void _setMultipleVariables(
      List<String> variables, Value value, FileSpan span) {
    var list = value.asList;
    var minLength = math.min(variables.length, list.length);
    for (var i = 0; i < minLength; i++) {
      _environment.setLocalVariable(variables[i], list[i].withoutSlash(), span);
    }
    for (var i = minLength; i < variables.length; i++) {
      _environment.setLocalVariable(variables[i], sassNull, span);
    }
  }

  Value visitErrorRule(ErrorRule node) {
    throw _exception(node.expression.accept(this).toString(), node.span);
  }

  Value visitExtendRule(ExtendRule node) {
    if (!_inStyleRule || _declarationName != null) {
      throw _exception(
          "@extend may only be used within style rules.", node.span);
    }

    var targetText = _interpolationToValue(node.selector, warnForColor: true);

    var list = _adjustParseError(
        targetText.span,
        () => new SelectorList.parse(targetText.value.trim(),
            logger: _logger, allowParent: false));

    for (var complex in list.components) {
      if (complex.components.length != 1 ||
          complex.components.first is! CompoundSelector) {
        // If the selector was a compound selector but not a simple
        // selector, emit a more explicit error.
        throw new SassFormatException(
            "complex selectors may not be extended.", targetText.span);
      }

      var compound = complex.components.first as CompoundSelector;
      if (compound.components.length != 1) {
        throw new SassFormatException(
            "compound selectors may longer be extended.\n"
            "Consider `@extend ${compound.components.join(', ')}` instead.\n"
            "See http://bit.ly/ExtendCompound for details.\n",
            targetText.span);
      }

      _extender.addExtension(
          _styleRule.selector, compound.components.first, node, _mediaQueries);
    }

    return null;
  }

  Value visitAtRule(AtRule node) {
    if (_declarationName != null) {
      throw _exception(
          "At-rules may not be used within nested declarations.", node.span);
    }

    var value = node.value == null
        ? null
        : _interpolationToValue(node.value, trim: true, warnForColor: true);

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
      if (!_inStyleRule) {
        for (var child in node.children) {
          child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the at-rule so that
        // declarations immediately inside it have somewhere to go.
        //
        // For example, "a {@foo {b: c}}" should produce "@foo {a {b: c}}".
        _withParent(_styleRule.copyWithoutChildren(), () {
          for (var child in node.children) {
            child.accept(this);
          }
        }, scopeWhen: false);
      }
    },
        through: (node) => node is CssStyleRule,
        scopeWhen: node.hasDeclarations);

    _inUnknownAtRule = wasInUnknownAtRule;
    _inKeyframes = wasInKeyframes;
    return null;
  }

  Value visitForRule(ForRule node) {
    var fromNumber = _addExceptionSpan(
        node.from.span, () => node.from.accept(this).assertNumber());
    var toNumber = _addExceptionSpan(
        node.to.span, () => node.to.accept(this).assertNumber());

    var from = _addExceptionSpan(
        node.from.span,
        () => fromNumber
            .coerce(toNumber.numeratorUnits, toNumber.denominatorUnits)
            .assertInt());
    var to = _addExceptionSpan(node.to.span, () => toNumber.assertInt());

    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return null;

    return _environment.scope(() {
      var span = _expressionSpan(node.from);
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(node.variable, new SassNumber(i), span);
        var result = _handleReturn<Statement>(
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
    var clause = node.lastClause;
    for (var clauseToCheck in node.clauses) {
      if (clauseToCheck.expression.accept(this).isTruthy) {
        clause = clauseToCheck;
        break;
      }
    }
    if (clause == null) return null;

    return _environment.scope(
        () => _handleReturn<Statement>(
            clause.children, (child) => child.accept(this)),
        semiGlobal: true,
        when: clause.hasDeclarations);
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
    var result = _loadImport(import);
    var importer = result.item1;
    var stylesheet = result.item2;

    var url = stylesheet.span.sourceUrl;
    if (_activeImports.contains(url)) {
      throw _exception("This file is already being imported.", import.span);
    }

    _activeImports.add(url);
    _withStackFrame("@import", import.span, () {
      _withEnvironment(_environment.closure(), () {
        var oldImporter = _importer;
        var oldStylesheet = _stylesheet;
        _importer = importer;
        _stylesheet = stylesheet;
        for (var statement in stylesheet.children) {
          statement.accept(this);
        }
        _importer = oldImporter;
        _stylesheet = oldStylesheet;
      });
    });
    _activeImports.remove(url);
  }

  /// Loads the [Stylesheet] imported by [import], or throws a
  /// [SassRuntimeException] if loading fails.
  Tuple2<Importer, Stylesheet> _loadImport(DynamicImport import) {
    try {
      if (_nodeImporter != null) {
        var stylesheet = _importLikeNode(import);
        if (stylesheet != null) return new Tuple2(null, stylesheet);
      } else {
        var tuple = _importCache.import(
            Uri.parse(import.url), _importer, _stylesheet.span?.sourceUrl);
        if (tuple != null) return tuple;
      }

      if (import.url.startsWith('package:')) {
        // Special-case this error message, since it's tripped people up in the
        // past.
        throw "\"package:\" URLs aren't supported on this platform.";
      } else {
        throw "Can't find stylesheet to import.";
      }
    } on SassException catch (error) {
      var frames = error.trace.frames.toList()
        ..addAll(_stackTrace(import.span).frames);
      throw new SassRuntimeException(
          error.message, error.span, new Trace(frames));
    } catch (error) {
      String message;
      try {
        message = error.message as String;
      } catch (_) {
        message = error.toString();
      }
      throw _exception(message, import.span);
    }
  }

  /// Imports a stylesheet using [_nodeImporter].
  ///
  /// Returns the [Stylesheet], or `null` if the import failed.
  Stylesheet _importLikeNode(DynamicImport import) {
    var result = _nodeImporter.load(import.url, _stylesheet.span?.sourceUrl);
    if (result == null) return null;

    var contents = result.item1;
    var url = result.item2;

    _includedFiles.add(url.startsWith('file:') ? p.fromUri(url) : url);

    return new Stylesheet.parse(
        contents, url.startsWith('file') ? Syntax.forPath(url) : Syntax.scss,
        url: url, logger: _logger);
  }

  /// Adds a CSS import for [import].
  void _visitStaticImport(StaticImport import) {
    var url = _interpolationToValue(import.url);
    var supports = import.supports;
    var resolvedSupports = supports is SupportsDeclaration
        ? "${_evaluateToCss(supports.name)}: "
            "${_evaluateToCss(supports.value)}"
        : (supports == null ? null : _visitSupportsCondition(supports));
    var mediaQuery =
        import.media == null ? null : _visitMediaQueries(import.media);

    var node = new CssImport(url, import.span,
        supports: resolvedSupports == null
            ? null
            : new CssValue("supports($resolvedSupports)", import.supports.span),
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
    var mixin =
        _environment.getMixin(node.name) as UserDefinedCallable<Environment>;
    if (mixin == null) {
      throw _exception("Undefined mixin.", node.span);
    }

    if (node.children != null && !(mixin.declaration as MixinRule).hasContent) {
      throw _exception("Mixin doesn't accept a content block.", node.span);
    }

    var environment = node.children == null ? null : _environment.closure();
    _runUserDefinedCallable(node.arguments, mixin, node.span, () {
      _environment.withContent(node.children, environment, () {
        _environment.asMixin(() {
          for (var statement in mixin.declaration.children) {
            statement.accept(this);
          }
        });
        return null;
      });
      return null;
    });

    return null;
  }

  Value visitMixinRule(MixinRule node) {
    _environment
        .setMixin(new UserDefinedCallable(node, _environment.closure()));
    return null;
  }

  Value visitLoudComment(LoudComment node) {
    if (_inFunction) return null;

    // Comments are allowed to appear between CSS imports.
    if (_parent == _root && _endOfImports == _root.children.length) {
      _endOfImports++;
    }

    _parent
        .addChild(new CssComment(_performInterpolation(node.text), node.span));
    return null;
  }

  Value visitMediaRule(MediaRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var queries = _visitMediaQueries(node.query);
    var mergedQueries = _mediaQueries == null
        ? null
        : _mergeMediaQueries(_mediaQueries, queries);
    if (mergedQueries != null && mergedQueries.isEmpty) return null;

    _withParent(new CssMediaRule(mergedQueries ?? queries, node.span), () {
      _withMediaQueries(mergedQueries ?? queries, () {
        if (!_inStyleRule) {
          for (var child in node.children) {
            child.accept(this);
          }
        } else {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          _withParent(_styleRule.copyWithoutChildren(), () {
            for (var child in node.children) {
              child.accept(this);
            }
          }, scopeWhen: false);
        }
      });
    },
        through: (node) =>
            node is CssStyleRule ||
            (mergedQueries != null && node is CssMediaRule),
        scopeWhen: node.hasDeclarations);

    return null;
  }

  /// Evaluates [interpolation] and parses the result as a list of media
  /// queries.
  List<CssMediaQuery> _visitMediaQueries(Interpolation interpolation) {
    var resolved = _performInterpolation(interpolation, warnForColor: true);

    // TODO(nweiz): Remove this type argument when sdk#31398 is fixed.
    return _adjustParseError<List<CssMediaQuery>>(interpolation.span,
        () => CssMediaQuery.parseList(resolved, logger: _logger));
  }

  /// Returns a list of queries that selects for contexts that match both
  /// [queries1] and [queries2].
  ///
  /// Returns the empty list if there are no contexts that match both [queries1]
  /// and [queries2], or `null` if there are contexts that can't be represented
  /// by media queries.
  List<CssMediaQuery> _mergeMediaQueries(
      Iterable<CssMediaQuery> queries1, Iterable<CssMediaQuery> queries2) {
    var queries = <CssMediaQuery>[];
    for (var query1 in queries1) {
      for (var query2 in queries2) {
        var result = query1.merge(query2);
        if (result == MediaQueryMergeResult.empty) continue;
        if (result == MediaQueryMergeResult.unrepresentable) return null;
        queries.add((result as MediaQuerySuccessfulMergeResult).query);
      }
    }
    return queries;
  }

  Value visitReturnRule(ReturnRule node) => node.expression.accept(this);

  Value visitSilentComment(SilentComment node) => null;

  Value visitStyleRule(StyleRule node) {
    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var selectorText =
        _interpolationToValue(node.selector, trim: true, warnForColor: true);
    if (_inKeyframes) {
      var parsedSelector = _adjustParseError(
          node.selector.span,
          () => new KeyframeSelectorParser(selectorText.value, logger: _logger)
              .parse());
      var rule = new CssKeyframeBlock(
          new CssValue(
              new List.unmodifiable(parsedSelector), node.selector.span),
          node.span);
      _withParent(rule, () {
        for (var child in node.children) {
          child.accept(this);
        }
      },
          through: (node) => node is CssStyleRule,
          scopeWhen: node.hasDeclarations);
      return null;
    }

    var parsedSelector = _adjustParseError(
        node.selector.span,
        () => new SelectorList.parse(selectorText.value,
            allowParent: !_stylesheet.plainCss,
            allowPlaceholder: !_stylesheet.plainCss,
            logger: _logger));
    parsedSelector = _addExceptionSpan(
        node.selector.span,
        () => parsedSelector.resolveParentSelectors(
            _styleRule?.originalSelector,
            implicitParent: !_atRootExcludingStyleRule));

    var selector =
        new CssValue<SelectorList>(parsedSelector, node.selector.span);

    var rule = _extender.addSelector(selector, node.span, _mediaQueries);
    var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
    _atRootExcludingStyleRule = false;
    _withParent(rule, () {
      _withStyleRule(rule, () {
        for (var child in node.children) {
          child.accept(this);
        }
      });
    },
        through: (node) => node is CssStyleRule,
        scopeWhen: node.hasDeclarations);
    _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;

    if (!_inStyleRule && _parent.children.isNotEmpty) {
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
      if (!_inStyleRule) {
        for (var child in node.children) {
          child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the supports rule so that
        // declarations immediately inside @supports have somewhere to go.
        //
        // For example, "a {@supports (a: b) {b: c}}" should produce "@supports
        // (a: b) {a {b: c}}".
        _withParent(_styleRule.copyWithoutChildren(), () {
          for (var child in node.children) {
            child.accept(this);
          }
        });
      }
    },
        through: (node) => node is CssStyleRule,
        scopeWhen: node.hasDeclarations);

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
      return _evaluateToCss(condition.expression, quote: false);
    } else if (condition is SupportsDeclaration) {
      return "(${_evaluateToCss(condition.name)}: "
          "${_evaluateToCss(condition.value)})";
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
        node.name,
        node.expression.accept(this).withoutSlash(),
        _expressionSpan(node.expression),
        global: node.isGlobal);
    return null;
  }

  Value visitWarnRule(WarnRule node) {
    var value =
        _addExceptionSpan(node.span, () => node.expression.accept(this));
    _logger.warn(
        value is SassString
            ? value.text
            : _serialize(value, node.expression.span),
        trace: _stackTrace(node.span));
    return null;
  }

  Value visitWhileRule(WhileRule node) {
    return _environment.scope(() {
      while (node.condition.accept(this).isTruthy) {
        var result = _handleReturn<Statement>(
            node.children, (child) => child.accept(this));
        if (result != null) return result;
      }
      return null;
    }, semiGlobal: true, when: node.hasDeclarations);
  }

  // ## Expressions

  Value visitBinaryOperationExpression(BinaryOperationExpression node) {
    return _addExceptionSpan(node.span, () {
      var left = node.left.accept(this);
      switch (node.operator) {
        case BinaryOperator.singleEquals:
          var right = node.right.accept(this);
          return left.singleEquals(right);

        case BinaryOperator.or:
          return left.isTruthy ? left : node.right.accept(this);

        case BinaryOperator.and:
          return left.isTruthy ? node.right.accept(this) : left;

        case BinaryOperator.equals:
          var right = node.right.accept(this);
          return new SassBoolean(left == right);

        case BinaryOperator.notEquals:
          var right = node.right.accept(this);
          return new SassBoolean(left != right);

        case BinaryOperator.greaterThan:
          var right = node.right.accept(this);
          return left.greaterThan(right);

        case BinaryOperator.greaterThanOrEquals:
          var right = node.right.accept(this);
          return left.greaterThanOrEquals(right);

        case BinaryOperator.lessThan:
          var right = node.right.accept(this);
          return left.lessThan(right);

        case BinaryOperator.lessThanOrEquals:
          var right = node.right.accept(this);
          return left.lessThanOrEquals(right);

        case BinaryOperator.plus:
          var right = node.right.accept(this);
          return left.plus(right);

        case BinaryOperator.minus:
          var right = node.right.accept(this);
          return left.minus(right);

        case BinaryOperator.times:
          var right = node.right.accept(this);
          return left.times(right);

        case BinaryOperator.dividedBy:
          var right = node.right.accept(this);
          var result = left.dividedBy(right);
          if (node.allowsSlash && left is SassNumber && right is SassNumber) {
            var leftSlash = left.asSlash ?? _serialize(left, node.left.span);
            var rightSlash = right.asSlash ?? _serialize(right, node.left.span);
            return (result as SassNumber).withSlash("$leftSlash/$rightSlash");
          } else {
            return result;
          }
          break;

        case BinaryOperator.modulo:
          var right = node.right.accept(this);
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

  Value visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  SassColor visitColorExpression(ColorExpression node) => node.value;

  SassList visitListExpression(ListExpression node) => new SassList(
      node.contents.map((Expression expression) => expression.accept(this)),
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

    var oldInFunction = _inFunction;
    _inFunction = true;
    var result = _runFunctionCallable(node.arguments, function, node.span);
    _inFunction = oldInFunction;
    return result;
  }

  /// Evaluates the arguments in [arguments] as applied to [callable], and
  /// invokes [run] in a scope with those arguments defined.
  Value _runUserDefinedCallable(ArgumentInvocation arguments,
      UserDefinedCallable<Environment> callable, FileSpan span, Value run()) {
    var evaluated = _evaluateArguments(arguments);

    return _withStackFrame(callable.name + "()", span, () {
      // Add an extra closure() call so that modifications to the environment
      // don't affect the underlying environment closure.
      return _withEnvironment(callable.environment.closure(), () {
        return _environment.scope(() {
          _verifyArguments(evaluated.positional.length, evaluated.named,
              callable.declaration.arguments, span);

          var declaredArguments = callable.declaration.arguments.arguments;
          var minLength =
              math.min(evaluated.positional.length, declaredArguments.length);
          for (var i = 0; i < minLength; i++) {
            _environment.setLocalVariable(
                declaredArguments[i].name,
                evaluated.positional[i].withoutSlash(),
                _sourceMap ? evaluated.positionalSpans[i] : null);
          }

          for (var i = evaluated.positional.length;
              i < declaredArguments.length;
              i++) {
            var argument = declaredArguments[i];
            var value = evaluated.named.remove(argument.name) ??
                argument.defaultValue.accept(this);
            _environment.setLocalVariable(
                argument.name,
                value.withoutSlash(),
                _sourceMap
                    ? evaluated.namedSpans[argument.name] ??
                        _expressionSpan(argument.defaultValue)
                    : null);
          }

          SassArgumentList argumentList;
          if (callable.declaration.arguments.restArgument != null) {
            var rest = evaluated.positional.length > declaredArguments.length
                ? evaluated.positional.sublist(declaredArguments.length)
                : const <Value>[];
            argumentList = new SassArgumentList(
                rest,
                evaluated.named,
                evaluated.separator == ListSeparator.undecided
                    ? ListSeparator.comma
                    : evaluated.separator);
            _environment.setLocalVariable(
                callable.declaration.arguments.restArgument,
                argumentList,
                span);
          }

          var result = run();

          if (argumentList == null) return result;
          if (evaluated.named.isEmpty) return result;
          if (argumentList.wereKeywordsAccessed) return result;

          var argumentWord = pluralize('argument', evaluated.named.keys.length);
          var argumentNames =
              toSentence(evaluated.named.keys.map((name) => "\$$name"), 'or');
          throw _exception("No $argumentWord named $argumentNames.", span);
        });
      });
    });
  }

  /// Evaluates [arguments] as applied to [callable].
  Value _runFunctionCallable(
      ArgumentInvocation arguments, Callable callable, FileSpan span) {
    if (callable is BuiltInCallable) {
      return _runBuiltInCallable(arguments, callable, span).withoutSlash();
    } else if (callable is UserDefinedCallable<Environment>) {
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

      var buffer = new StringBuffer("${callable.name}(");
      var first = true;
      for (var argument in arguments.positional) {
        if (first) {
          first = false;
        } else {
          buffer.write(", ");
        }

        buffer.write(_evaluateToCss(argument));
      }

      var rest = arguments.rest?.accept(this);
      if (rest != null) {
        if (!first) buffer.write(", ");
        buffer.write(_serialize(rest, arguments.rest.span));
      }
      buffer.writeCharCode($rparen);

      return new SassString(buffer.toString(), quotes: false);
    } else {
      return null;
    }
  }

  /// Evaluates [invocation] as applied to [callable], and invokes [callable]'s
  /// body.
  Value _runBuiltInCallable(
      ArgumentInvocation arguments, BuiltInCallable callable, FileSpan span) {
    var evaluated = _evaluateArguments(arguments, trackSpans: false);

    var oldCallableSpan = _callableSpan;
    _callableSpan = span;

    var namedSet = new MapKeySet(evaluated.named);
    var tuple = callable.callbackFor(evaluated.positional.length, namedSet);
    var overload = tuple.item1;
    var callback = tuple.item2;
    _addExceptionSpan(
        span, () => overload.verify(evaluated.positional.length, namedSet));

    var declaredArguments = overload.arguments;
    for (var i = evaluated.positional.length;
        i < declaredArguments.length;
        i++) {
      var argument = declaredArguments[i];
      evaluated.positional.add(evaluated.named.remove(argument.name) ??
          argument.defaultValue?.accept(this));
    }

    SassArgumentList argumentList;
    if (overload.restArgument != null) {
      var rest = const <Value>[];
      if (evaluated.positional.length > declaredArguments.length) {
        rest = evaluated.positional.sublist(declaredArguments.length);
        evaluated.positional
            .removeRange(declaredArguments.length, evaluated.positional.length);
      }

      argumentList = new SassArgumentList(
          rest,
          evaluated.named,
          evaluated.separator == ListSeparator.undecided
              ? ListSeparator.comma
              : evaluated.separator);
      evaluated.positional.add(argumentList);
    }

    Value result;
    try {
      result = callback(evaluated.positional);
      if (result == null) throw "Custom functions may not return Dart's null.";
    } catch (error) {
      String message;
      try {
        message = error.message as String;
      } catch (_) {
        message = error.toString();
      }
      throw _exception(message, span);
    }
    _callableSpan = oldCallableSpan;

    if (argumentList == null) return result;
    if (evaluated.named.isEmpty) return result;
    if (argumentList.wereKeywordsAccessed) return result;
    throw _exception(
        "No ${pluralize('argument', evaluated.named.keys.length)} named "
        "${toSentence(evaluated.named.keys.map((name) => "\$$name"), 'or')}.",
        span);
  }

  /// Returns the evaluated values of the given [arguments].
  ///
  /// If [trackSpans] is `true`, this tracks the source spans of the arguments
  /// being passed in. It defaults to [_sourceMap].
  _ArgumentResults _evaluateArguments(ArgumentInvocation arguments,
      {bool trackSpans}) {
    trackSpans ??= _sourceMap;

    var positional = arguments.positional
        .map((Expression expression) => expression.accept(this))
        .toList();
    var named = normalizedMapMap<String, Expression, Value>(arguments.named,
        value: (_, expression) => expression.accept(this));

    var positionalSpans =
        trackSpans ? arguments.positional.map(_expressionSpan).toList() : null;
    var namedSpans = trackSpans
        ? mapMap<String, Expression, String, FileSpan>(arguments.named,
            value: (_, expression) => _expressionSpan(expression))
        : null;

    if (arguments.rest == null) {
      return new _ArgumentResults(positional, named, ListSeparator.undecided,
          positionalSpans: positionalSpans, namedSpans: namedSpans);
    }

    var rest = arguments.rest.accept(this);
    var restSpan = trackSpans ? _expressionSpan(arguments.rest) : null;
    var separator = ListSeparator.undecided;
    if (rest is SassMap) {
      _addRestMap(named, rest, arguments.rest.span);
      namedSpans?.addAll(mapMap(rest.contents,
          key: (key, _) => (key as SassString).text,
          value: (_, __) => restSpan));
    } else if (rest is SassList) {
      positional.addAll(rest.asList);
      positionalSpans?.addAll(new List.filled(rest.lengthAsList, restSpan));
      separator = rest.separator;

      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = value;
          if (namedSpans != null) namedSpans[key] = restSpan;
        });
      }
    } else {
      positional.add(rest);
      positionalSpans?.add(restSpan);
    }

    if (arguments.keywordRest == null) {
      return new _ArgumentResults(positional, named, separator,
          positionalSpans: positionalSpans, namedSpans: namedSpans);
    }

    var keywordRest = arguments.keywordRest.accept(this);
    var keywordRestSpan =
        trackSpans ? _expressionSpan(arguments.keywordRest) : null;
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, arguments.keywordRest.span);
      namedSpans?.addAll(mapMap(keywordRest.contents,
          key: (key, _) => (key as SassString).text,
          value: (_, __) => keywordRestSpan));
      return new _ArgumentResults(positional, named, separator,
          positionalSpans: positionalSpans, namedSpans: namedSpans);
    } else {
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).",
          arguments.keywordRest.span);
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
  void _addRestMap<T>(Map<String, T> values, SassMap map, FileSpan span,
      [T convert(Value value)]) {
    convert ??= (value) => value as T;
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
          ArgumentDeclaration arguments, FileSpan span) =>
      _addExceptionSpan(
          span, () => arguments.verify(positional, new MapKeySet(named)));

  Value visitSelectorExpression(SelectorExpression node) {
    if (_styleRule == null) return sassNull;
    return _styleRule.originalSelector.asSassList;
  }

  SassString visitStringExpression(StringExpression node) {
    // Don't use [performInterpolation] here because we need to get the raw text
    // from strings, rather than the semantic value.
    return new SassString(
        node.text.contents.map((value) {
          if (value is String) return value;
          var expression = value as Expression;
          var result = expression.accept(this);
          return result is SassString
              ? result.text
              : _serialize(result, expression.span, quote: false);
        }).join(),
        quotes: node.hasQuotes);
  }

  // ## Utilities

  /// Runs [callback] for each value in [list] until it returns a [Value].
  ///
  /// Returns the value returned by [callback], or `null` if it only ever
  /// returned `null`.
  Value _handleReturn<T>(List<T> list, Value callback(T value)) {
    for (var value in list) {
      var result = callback(value);
      if (result != null) return result;
    }
    return null;
  }

  /// Runs [callback] with [environment] as the current environment.
  T _withEnvironment<T>(Environment environment, T callback()) {
    var oldEnvironment = _environment;
    _environment = environment;
    var result = callback();
    _environment = oldEnvironment;
    return result;
  }

  /// Evaluates [interpolation] and wraps the result in a [CssValue].
  ///
  /// If [trim] is `true`, removes whitespace around the result. If
  /// [warnForColor] is `true`, this will emit a warning for any named color
  /// values passed into the interpolation.
  CssValue<String> _interpolationToValue(Interpolation interpolation,
      {bool trim: false, bool warnForColor: false}) {
    var result =
        _performInterpolation(interpolation, warnForColor: warnForColor);
    return new CssValue(trim ? result.trim() : result, interpolation.span);
  }

  /// Evaluates [interpolation].
  ///
  /// If [warnForColor] is `true`, this will emit a warning for any named color
  /// values passed into the interpolation.
  String _performInterpolation(Interpolation interpolation,
      {bool warnForColor: false}) {
    return interpolation.contents.map((value) {
      if (value is String) return value;
      var expression = value as Expression;
      var result = expression.accept(this);

      if (warnForColor &&
          result is SassColor &&
          namesByColor.containsKey(result)) {
        var alternative = new BinaryOperationExpression(
            BinaryOperator.plus,
            new StringExpression(new Interpolation([""], null), quotes: true),
            expression);
        _warn(
            "You probably don't mean to use the color value "
            "${namesByColor[result]} in interpolation here.\n"
            "It may end up represented as $result, which will likely produce "
            "invalid CSS.\n"
            "Always quote color names when using them as strings or map keys "
            '(for example, "${namesByColor[result]}").\n'
            "If you really want to use the color value here, use '$alternative'.",
            expression.span);
      }

      return _serialize(result, expression.span, quote: false);
    }).join();
  }

  /// Evaluates [expression] and calls `toCssString()` and wraps a
  /// [SassScriptException] to associate it with [span].
  String _evaluateToCss(Expression expression, {bool quote: true}) =>
      _serialize(expression.accept(this), expression.span, quote: quote);

  /// Calls `value.toCssString()` and wraps a [SassScriptException] to associate
  /// it with [span].
  String _serialize(Value value, FileSpan span, {bool quote: true}) =>
      _addExceptionSpan(span, () => value.toCssString(quote: quote));

  /// Returns the span for [expression], or if [expression] is just a variable
  /// reference for the span where it was declared.
  ///
  /// Returns `null` if [_sourceMap] is `false`.
  FileSpan _expressionSpan(Expression expression) {
    if (!_sourceMap) return null;
    if (expression is VariableExpression) {
      return _environment.getVariableSpan(expression.name);
    } else {
      return expression.span;
    }
  }

  /// Adds [node] as a child of the current parent, then runs [callback] with
  /// [node] as the current parent.
  ///
  /// If [through] is passed, [node] is added as a child of the first parent for
  /// which [through] returns `false`. That parent is copied unless it's the
  /// lattermost child of its parent.
  ///
  /// Runs [callback] in a new environment scope unless [scopeWhen] is false.
  T _withParent<S extends CssParentNode, T>(S node, T callback(),
      {bool through(CssNode node), bool scopeWhen: true}) {
    var oldParent = _parent;

    // Go up through parents that match [through].
    var parent = _parent;
    if (through != null) {
      while (through(parent)) {
        parent = parent.parent;
      }

      // If the parent has a (visible) following sibling, we shouldn't add to
      // the parent. Instead, we should create a copy and add it after the
      // interstitial sibling.
      if (parent.hasFollowingSibling) {
        var grandparent = parent.parent;
        parent = parent.copyWithoutChildren();
        grandparent.addChild(parent);
      }
    }

    parent.addChild(node);
    _parent = node;
    var result = _environment.scope(callback, when: scopeWhen);
    _parent = oldParent;

    return result;
  }

  /// Runs [callback] with [rule] as the current style rule.
  T _withStyleRule<T>(CssStyleRule rule, T callback()) {
    var oldRule = _styleRule;
    _styleRule = rule;
    var result = callback();
    _styleRule = oldRule;
    return result;
  }

  /// Runs [callback] with [queries] as the current media queries.
  T _withMediaQueries<T>(List<CssMediaQuery> queries, T callback()) {
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
  T _withStackFrame<T>(String member, FileSpan span, T callback()) {
    _stack.add(new Tuple2(_member, span));
    var oldMember = _member;
    _member = member;
    var result = callback();
    _member = oldMember;
    _stack.removeLast();
    return result;
  }

  /// Creates a new stack frame with location information from [member] and
  /// [span].
  Frame _stackFrame(String member, FileSpan span) => frameForSpan(span, member,
      url: span.sourceUrl == null
          ? null
          : _importCache.humanize(span.sourceUrl));

  /// Returns a stack trace at the current point.
  ///
  /// [span] is the current location, used for the bottom-most stack frame.
  Trace _stackTrace(FileSpan span) {
    var frames = _stack
        .map((tuple) => _stackFrame(tuple.item1, tuple.item2))
        .toList()
          ..add(_stackFrame(_member, span));
    return new Trace(frames.reversed);
  }

  /// Emits a warning with the given [message] about the given [span].
  void _warn(String message, FileSpan span, {bool deprecation: false}) =>
      _logger.warn(message,
          span: span, trace: _stackTrace(span), deprecation: deprecation);

  /// Throws a [SassRuntimeException] with the given [message] and [span].
  SassRuntimeException _exception(String message, FileSpan span) =>
      new SassRuntimeException(message, span, _stackTrace(span));

  /// Runs [callback], and adjusts any [SassFormatException] to be within [span].
  ///
  /// Specifically, this adjusts format exceptions so that the errors are
  /// reported as though the text being parsed were exactly in [span]. This may
  /// not be quite accurate if the source text contained interpolation, but
  /// it'll still produce a useful error.
  T _adjustParseError<T>(FileSpan span, T callback()) {
    try {
      return callback();
    } on SassFormatException catch (error) {
      var errorText = error.span.file.getText(0);
      var syntheticFile = span.file
          .getText(0)
          .replaceRange(span.start.offset, span.end.offset, errorText);
      var syntheticSpan =
          new SourceFile.fromString(syntheticFile, url: span.file.url).span(
              span.start.offset + error.span.start.offset,
              span.start.offset + error.span.end.offset);
      throw _exception(error.message, syntheticSpan);
    }
  }

  /// Runs [callback], and converts any [SassScriptException]s it throws to
  /// [SassRuntimeException]s with [span].
  T _addExceptionSpan<T>(FileSpan span, T callback()) {
    try {
      return callback();
    } on SassScriptException catch (error) {
      throw _exception(error.message, span);
    }
  }
}

/// The result of evaluating arguments to a function or mixin.
class _ArgumentResults {
  /// Arguments passed by position.
  final List<Value> positional;

  /// The spans for each [positional] argument, or `null` if source span
  /// tracking is disabled.
  final List<FileSpan> positionalSpans;

  /// Arguments passed by name.
  final Map<String, Value> named;

  /// The spans for each [named] argument, or `null` if source span tracking is
  /// disabled.
  final Map<String, FileSpan> namedSpans;

  /// The separator used for the rest argument list, if any.
  final ListSeparator separator;

  _ArgumentResults(this.positional, this.named, this.separator,
      {this.positionalSpans, this.namedSpans});
}
