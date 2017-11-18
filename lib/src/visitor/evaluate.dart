// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_evaluate.dart.
// See tool/synchronize.dart for details.
//
// Checksum: ef8fa3966d7580d8511d8d8430a8f65cd9cb9018

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../environment.dart';
import '../callable.dart';
import '../color_names.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../importer.dart';
import '../importer/node.dart';
import '../io.dart';
import '../parse/keyframe_selector.dart';
import '../utils.dart';
import '../util/path.dart';
import '../value.dart';
import 'interface/statement.dart';
import 'interface/expression.dart';

/// A function that takes a callback with no arguments.
typedef void _ScopeCallback(void callback());

/// The URL used in stack traces when no source URL is available.
final _noSourceUrl = Uri.parse("-");

/// The default URL to pass in to Node importers for previous imports.
final _defaultPrevious = new Uri(path: 'stdin');

/// Converts [stylesheet] to a plain CSS tree.
///
/// If [importers] (or, on Node.js, [nodeImporter]) is passed, it's used to
/// resolve imports in the Sass files. Earlier importers will be preferred.
///
/// If [environment] is passed, it's used as the lexical environment when
/// evaluating [stylesheet]. It should only contain global definitions.
///
/// If [color] is `true`, this will use terminal colors in warnings.
///
/// If [importer] is passed, it's used to resolve relative imports in
/// [stylesheet] relative to `stylesheet.span.sourceUrl`.
///
/// Throws a [SassRuntimeException] if evaluation fails.
EvaluateResult evaluate(Stylesheet stylesheet,
        {Iterable<Importer> importers,
        NodeImporter nodeImporter,
        Importer importer,
        Environment environment,
        bool color: false}) =>
    new _EvaluateVisitor(
            importers: importers,
            nodeImporter: nodeImporter,
            importer: importer,
            environment: environment,
            color: color)
        .run(stylesheet);

/// A visitor that executes Sass code to produce a CSS tree.
class _EvaluateVisitor
    implements StatementVisitor<Value>, ExpressionVisitor<Value> {
  /// The importers to use when loading new Sass files.
  final List<Importer> _importers;

  /// The Node Sass-compatible importer to use when loading new Sass files when
  /// compiled to Node.js.
  final NodeImporter _nodeImporter;

  /// Whether to use terminal colors in warnings.
  final bool _color;

  /// The current lexical environment.
  Environment _environment;

  /// The importer that's currently being used to resolve relative imports.
  ///
  /// If this is `null`, relative imports aren't supported in the current
  /// stylesheet.
  Importer _importer;

  /// The base URL to use for resolving relative imports.
  Uri _baseUrl;

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

  /// The parsed stylesheets for each canonicalized import URL.
  final _importCache = <Uri, Stylesheet>{};

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
  final _stack = <Frame>[];

  /// Whether we're running in Node Sass-compatibility mode.
  bool get _asNodeSass => _nodeImporter != null;

  _EvaluateVisitor(
      {Iterable<Importer> importers,
      NodeImporter nodeImporter,
      Importer importer,
      Environment environment,
      bool color: false})
      : _importers = importers == null ? const [] : importers.toList(),
        _importer = importer ?? Importer.noOp,
        _nodeImporter = nodeImporter,
        _environment = environment ?? new Environment(),
        _color = color {
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
                      key: (String key, Value _) => new SassString(key),
                      value: (String _, Value value) => value)),
                  _callableSpan));

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

      var callable = function.assertFunction("function").callable;
      if (callable is Callable) {
        return _runFunctionCallable(invocation, callable, _callableSpan);
      } else {
        throw new SassScriptException(
            "The function ${callable.name} is asynchronous.\n"
            "This is probably caused by a bug in a Sass plugin.");
      }
    }));
  }

  EvaluateResult run(Stylesheet node) {
    _baseUrl = node.span?.sourceUrl;
    if (_baseUrl != null) {
      if (_asNodeSass) {
        if (_baseUrl.scheme == 'file') {
          _includedFiles.add(p.fromUri(_baseUrl));
        } else if (_baseUrl.toString() != 'stdin') {
          _includedFiles.add(_baseUrl.toString());
        }
      }

      var canonicalUrl = _importer?.canonicalize(_baseUrl);
      if (canonicalUrl != null) {
        _activeImports.add(canonicalUrl);
        _importCache[canonicalUrl] = node;
      }
    }
    _baseUrl ??= new Uri(path: '.');

    visitStylesheet(node);

    return new EvaluateResult(_root, _includedFiles);
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
    var query = AtRootQuery.defaultQuery;
    if (node.query != null) {
      var resolved = _performInterpolation(node.query, warnForColor: true);
      query = _adjustParseError(
          node.query.span, () => new AtRootQuery.parse(resolved));
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
      });
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
    var scope = (void callback()) {
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
    var start = node.span.start;
    var value = node.expression.accept(this);
    stderr.writeln("${p.prettyUri(start.sourceUrl)}:${start.line + 1} DEBUG: "
        "${value is SassString ? value.text : value}");
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
      _environment.scope(() {
        for (var child in node.children) {
          child.accept(this);
        }
      });
      _declarationName = oldDeclarationName;
    }

    return null;
  }

  /// Returns whether [value] is an empty [SassList].
  bool _isEmptyList(Value value) => value is SassList && value.contents.isEmpty;

  Value visitEachRule(EachRule node) {
    var list = node.list.accept(this);
    var setVariables = node.variables.length == 1
        ? (Value value) => _environment.setLocalVariable(
            node.variables.first, value.withoutSlash())
        : (Value value) => _setMultipleVariables(node.variables, value);
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
  void _setMultipleVariables(List<String> variables, Value value) {
    var list = value.asList;
    var minLength = math.min(variables.length, list.length);
    for (var i = 0; i < minLength; i++) {
      _environment.setLocalVariable(variables[i], list[i].withoutSlash());
    }
    for (var i = minLength; i < variables.length; i++) {
      _environment.setLocalVariable(variables[i], sassNull);
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

    var target = _adjustParseError(
        targetText.span,
        () => new SimpleSelector.parse(targetText.value.trim(),
            allowParent: false));
    _extender.addExtension(_styleRule.selector, target, node, _mediaQueries);
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
        });
      }
    }, through: (node) => node is CssStyleRule);

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

    // TODO: coerce units
    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return null;

    return _environment.scope(() {
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(node.variable, new SassNumber(i));
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
    for (var pair in node.clauses) {
      if (pair.item1.accept(this).isTruthy) {
        clause = pair.item2;
        break;
      }
    }
    if (clause == null) return null;

    return _environment.scope(
        () => _handleReturn<Statement>(clause, (child) => child.accept(this)),
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
    var result = _loadImport(import);
    var importer = result.item1;
    var stylesheet = result.item2;

    var url = stylesheet.span.sourceUrl;
    if (_activeImports.contains(url)) {
      throw _exception("This file is already being imported.", import.span);
    }

    _activeImports.add(url);
    _withStackFrame("@import", import.span, () {
      _withEnvironment(_environment.global(), () {
        var oldImporter = _importer;
        var oldBaseUrl = _baseUrl;
        _importer = importer;
        _baseUrl = url;
        for (var statement in stylesheet.children) {
          statement.accept(this);
        }
        _importer = oldImporter;
        _baseUrl = oldBaseUrl;
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
        // Try to resolve [import.url] relative to the current URL with the
        // current importer.
        if (import.url.scheme.isEmpty && _importer != null) {
          var stylesheet =
              _tryImport(_importer, _baseUrl.resolveUri(import.url));
          if (stylesheet != null) return new Tuple2(_importer, stylesheet);
        }

        for (var importer in _importers) {
          var stylesheet = _tryImport(importer, import.url);
          if (stylesheet != null) return new Tuple2(importer, stylesheet);
        }
      }

      if (import.url.scheme == 'package') {
        // Special-case this error message, since it's tripped people up in the
        // past.
        throw "\"package:\" URLs aren't supported on this platform.";
      } else {
        throw "Can't find stylesheet to import.";
      }
    } on SassException catch (error) {
      var frames = error.trace.frames.toList()
        ..add(_stackFrame(import.span))
        ..addAll(_stack.toList());
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
    var result = _nodeImporter.load(import.url, _baseUrl);
    if (result == null) return null;

    var contents = result.item1;
    var url = result.item2;

    if (url.scheme == 'file') {
      _includedFiles.add(p.fromUri(url));
    } else {
      _includedFiles.add(url.toString());
    }

    return url.scheme == 'file' && pUrl.extension(url.path) == '.sass'
        ? new Stylesheet.parseSass(contents, url: url, color: _color)
        : new Stylesheet.parseScss(contents, url: url, color: _color);
  }

  /// Parses the contents of [result] into a [Stylesheet].
  Stylesheet _tryImport(Importer importer, Uri url) {
    // TODO(nweiz): Measure to see if it's worth caching this, too.
    var canonicalUrl = importer.canonicalize(url);
    if (canonicalUrl == null) return null;

    return _importCache.putIfAbsent(canonicalUrl, () {
      var result = importer.load(canonicalUrl);
      if (result == null) return null;

      // Use the canonicalized basename so that we display e.g.
      // package:example/_example.scss rather than package:example/example in
      // stack traces.
      var displayUrl = url.resolve(p.basename(canonicalUrl.path));
      return result.isIndented
          ? new Stylesheet.parseSass(result.contents,
              url: displayUrl, color: _color)
          : new Stylesheet.parseScss(result.contents,
              url: displayUrl, color: _color);
    });
  }

  /// Adds a CSS import for [import].
  void _visitStaticImport(StaticImport import) {
    var url = _interpolationToValue(import.url);
    var supports = import.supports;
    var resolvedSupports = supports is SupportsDeclaration
        ? "(${_evaluateToCss(supports.name)}: "
            "${_evaluateToCss(supports.value)})"
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
    if (_mediaQueries != null) {
      queries = _mergeMediaQueries(_mediaQueries, queries);
      if (queries.isEmpty) return null;
    }

    _withParent(new CssMediaRule(queries, node.span), () {
      _withMediaQueries(queries, () {
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
          });
        }
      });
    }, through: (node) => node is CssStyleRule || node is CssMediaRule);

    return null;
  }

  /// Evaluates [interpolation] and parses the result as a list of media
  /// queries.
  List<CssMediaQuery> _visitMediaQueries(Interpolation interpolation) {
    var resolved = _performInterpolation(interpolation, warnForColor: true);

    // TODO(nweiz): Remove this type argument when sdk#31398 is fixed.
    return _adjustParseError<List<CssMediaQuery>>(
        interpolation.span, () => CssMediaQuery.parseList(resolved));
  }

  /// Returns a list of queries that selects for platforms that match both
  /// [queries1] and [queries2].
  List<CssMediaQuery> _mergeMediaQueries(
      Iterable<CssMediaQuery> queries1, Iterable<CssMediaQuery> queries2) {
    return new List.unmodifiable(queries1.expand((query1) {
      return queries2.map((query2) => query1.merge(query2));
    }).where((query) => query != null));
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
    }, through: (node) => node is CssStyleRule);
    _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;

    if (!_inStyleRule) {
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
        node.name, node.expression.accept(this).withoutSlash(),
        global: node.isGlobal);
    return null;
  }

  Value visitWarnRule(WarnRule node) {
    _addExceptionSpan(node.span, () {
      var value = node.expression.accept(this);
      var string = value is SassString
          ? value.text
          : _serialize(value, node.expression.span);
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
        var result = _handleReturn<Statement>(
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
    var triple = _evaluateArguments(arguments, span);
    var positional = triple.item1;
    var named = triple.item2;
    var separator = triple.item3;

    return _withStackFrame(callable.name + "()", span, () {
      // Add an extra closure() call so that modifications to the environment
      // don't affect the underlying environment closure.
      return _withEnvironment(callable.environment.closure(), () {
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
                declaredArguments[i].name, positional[i].withoutSlash());
          }

          for (var i = positional.length; i < declaredArguments.length; i++) {
            var argument = declaredArguments[i];
            var value = named.remove(argument.name) ??
                argument.defaultValue?.accept(this);
            _environment.setLocalVariable(argument.name, value?.withoutSlash());
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

      return new SassString(buffer.toString());
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
    var separator = triple.item3;

    var oldCallableSpan = _callableSpan;
    _callableSpan = span;

    var namedSet = new MapKeySet(named);
    var tuple = callable.callbackFor(positional.length, namedSet);
    var overload = tuple.item1;
    var callback = tuple.item2;
    _addExceptionSpan(span, () => overload.verify(positional.length, namedSet));

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
        .map((Expression expression) => expression.accept(this))
        .toList();
    var named = normalizedMapMap<String, Expression, Value>(arguments.named,
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
        warn(
            "You probably don't mean to use the color value "
            "${namesByColor[result]} in interpolation here.\n"
            "It may end up represented as $result, which will likely produce "
            "invalid CSS.\n"
            "Always quote color names when using them as strings or map keys "
            '(for example, "${namesByColor[result]}").\n'
            "If you really want to use the color value here, use '$alternative'.\n",
            expression.span);
      }

      return _serialize(result, expression.span, quote: false);
    }).join();
  }

  /// Evaluates [expression] and wraps the result in a [CssValue].
  CssValue<Value> _performExpression(Expression expression) =>
      new CssValue(expression.accept(this), expression.span);

  /// Evaluates [expression] and calls `toCssString()` and wraps a
  /// [SassScriptException] to associate it with [span].
  String _evaluateToCss(Expression expression, {bool quote: true}) =>
      _serialize(expression.accept(this), expression.span, quote: quote);

  /// Calls `value.toCssString()` and wraps a [SassScriptException] to associate
  /// it with [span].
  String _serialize(Value value, FileSpan span, {bool quote: true}) =>
      _addExceptionSpan(span, () => value.toCssString(quote: quote));

  /// Adds [node] as a child of the current parent, then runs [callback] with
  /// [node] as the current parent.
  ///
  /// If [through] is passed, [node] is added as a child of the first parent for
  /// which [through] returns `false`. That parent is copied unless it's the
  /// lattermost child of its parent.
  T _withParent<S extends CssParentNode, T>(S node, T callback(),
      {bool through(CssNode node)}) {
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
    var result = _environment.scope(callback);
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
  Frame _stackFrame(FileSpan span) => frameForSpan(span, _member);

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

/// The result of compiling a Sass document to a CSS tree, along with metadata
/// about the compilation process.
class EvaluateResult {
  /// The CSS syntax tree.
  final CssStylesheet stylesheet;

  /// The set that will eventually populate the JS API's
  /// `result.stats.includedFiles` field.
  ///
  /// For filesystem imports, this contains the import path. For all other
  /// imports, it contains the URL passed to the `@import`.
  final Set<String> includedFiles;

  EvaluateResult(this.stylesheet, this.includedFiles);
}
