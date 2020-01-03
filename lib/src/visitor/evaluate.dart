// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_evaluate.dart.
// See tool/grind/synchronize.dart for details.
//
// Checksum: 98bd4418d21d4f005485e343869b458b44841450
//
// ignore_for_file: unused_import

import 'async_evaluate.dart' show EvaluateResult;
export 'async_evaluate.dart' show EvaluateResult;

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/css/modifiable.dart';
import '../ast/node.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../environment.dart';
import '../import_cache.dart';
import '../callable.dart';
import '../color_names.dart';
import '../configuration.dart';
import '../configured_value.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../extend/extension.dart';
import '../functions.dart';
import '../functions/meta.dart' as meta;
import '../importer.dart';
import '../importer/node.dart';
import '../io.dart';
import '../logger.dart';
import '../module.dart';
import '../module/built_in.dart';
import '../parse/keyframe_selector.dart';
import '../syntax.dart';
import '../util/fixed_length_list_builder.dart';
import '../utils.dart';
import '../value.dart';
import '../warn.dart';
import 'interface/css.dart';
import 'interface/expression.dart';
import 'interface/modifiable_css.dart';
import 'interface/statement.dart';

/// A function that takes a callback with no arguments.
typedef _ScopeCallback = void Function(void Function() callback);

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
        Logger logger,
        bool sourceMap = false}) =>
    _EvaluateVisitor(
            importCache: importCache,
            nodeImporter: nodeImporter,
            functions: functions,
            logger: logger,
            sourceMap: sourceMap)
        .run(importer, stylesheet);

/// A class that can evaluate multiple independent statements and expressions
/// in the context of a single module.
class Evaluator {
  /// The visitor that evaluates each expression and statement.
  final _EvaluateVisitor _visitor;

  /// The importer to use to resolve `@use` rules in [_importer].
  final Importer _importer;

  /// Creates an evaluator.
  ///
  /// Arguments are the same as for [evaluate].
  Evaluator(
      {ImportCache importCache,
      Importer importer,
      Iterable<Callable> functions,
      Logger logger})
      : _visitor = _EvaluateVisitor(
            importCache: importCache, functions: functions, logger: logger),
        _importer = importer;

  void use(UseRule use) => _visitor.runStatement(_importer, use);

  Value evaluate(Expression expression) =>
      _visitor.runExpression(_importer, expression);

  void setVariable(VariableDeclaration declaration) =>
      _visitor.runStatement(_importer, declaration);
}

/// A visitor that executes Sass code to produce a CSS tree.
class _EvaluateVisitor
    implements
        StatementVisitor<Value>,
        ExpressionVisitor<Value>,
        CssVisitor<void> {
  /// The import cache used to import other stylesheets.
  final ImportCache _importCache;

  /// The Node Sass-compatible importer to use when loading new Sass files when
  /// compiled to Node.js.
  final NodeImporter _nodeImporter;

  /// Built-in functions that are globally-acessible, even under the new module
  /// system.
  final _builtInFunctions = <String, Callable>{};

  /// Built in modules, indexed by their URLs.
  final _builtInModules = <Uri, Module<Callable>>{};

  /// All modules that have been loaded and evaluated so far.
  final _modules = <Uri, Module<Callable>>{};

  /// The logger to use to print warnings.
  final Logger _logger;

  /// Whether to track source map information.
  final bool _sourceMap;

  /// The current lexical environment.
  Environment _environment;

  /// The style rule that defines the current parent selector, if any.
  ModifiableCssStyleRule _styleRule;

  /// The current media queries, if any.
  List<CssMediaQuery> _mediaQueries;

  /// The current parent node in the output CSS tree.
  ModifiableCssParentNode _parent;

  /// The name of the current declaration parent.
  String _declarationName;

  /// The human-readable name of the current stack frame.
  var _member = "root stylesheet";

  /// The node for the innermost callable that's being invoked.
  ///
  /// This is used to produce warnings for function calls. It's stored as an
  /// [AstNode] rather than a [FileSpan] so we can avoid calling [AstNode.span]
  /// if the span isn't required, since some nodes need to do real work to
  /// manufacture a source span.
  AstNode _callableNode;

  /// The span for the current import that's being resolved.
  ///
  /// This is used to produce warnings for importers.
  FileSpan _importSpan;

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

  /// The set that will eventually populate the JS API's
  /// `result.stats.includedFiles` field.
  ///
  /// For filesystem imports, this contains the import path. For all other
  /// imports, it contains the URL passed to the `@import`.
  final _includedFiles = <String>{};

  /// The set of canonical URLs for modules (or imported files) that are
  /// currently being evaluated.
  ///
  /// This is used to ensure that we don't get into an infinite load loop.
  final _activeModules = <Uri>{};

  /// The dynamic call stack representing function invocations, mixin
  /// invocations, and imports surrounding the current context.
  ///
  /// Each member is a tuple of the span where the stack trace starts and the
  /// name of the member being invoked.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final _stack = <Tuple2<String, AstNode>>[];

  /// Whether we're running in Node Sass-compatibility mode.
  bool get _asNodeSass => _nodeImporter != null;

  // ## Module-Specific Fields

  /// The importer that's currently being used to resolve relative imports.
  ///
  /// If this is `null`, relative imports aren't supported in the current
  /// stylesheet.
  Importer _importer;

  /// The stylesheet that's currently being evaluated.
  Stylesheet _stylesheet;

  /// The root stylesheet node.
  ModifiableCssStylesheet _root;

  /// The first index in [_root.children] after the initial block of CSS
  /// imports.
  int _endOfImports;

  /// Plain-CSS imports that didn't appear in the initial block of CSS imports.
  ///
  /// These are added to the initial CSS import block by [visitStylesheet] after
  /// the stylesheet has been fully performed.
  ///
  /// This is `null` unless there are any out-of-order imports in the current
  /// stylesheet.
  List<ModifiableCssImport> _outOfOrderImports;

  /// The extender that tracks extensions and style rules for the current
  /// module.
  Extender _extender;

  /// The configuration for the current module.
  ///
  /// If this is empty, that indicates that the current module is not confiured.
  var _configuration = const Configuration.empty();

  /// Creates a new visitor.
  ///
  /// Most arguments are the same as those to [evaluate].
  _EvaluateVisitor(
      {ImportCache importCache,
      NodeImporter nodeImporter,
      Iterable<Callable> functions,
      Logger logger,
      bool sourceMap = false})
      : _importCache = nodeImporter == null
            ? importCache ?? ImportCache.none(logger: logger)
            : null,
        _nodeImporter = nodeImporter,
        _logger = logger ?? const Logger.stderr(),
        _sourceMap = sourceMap,
        // The default environment is overridden in [_execute] for full
        // stylesheets, but for [AsyncEvaluator] this environment is used.
        _environment = Environment(sourceMap: sourceMap) {
    var metaFunctions = [
      // These functions are defined in the context of the evaluator because
      // they need access to the [_environment] or other local state.
      BuiltInCallable("global-variable-exists", r"$name, $module: null",
          (arguments) {
        var variable = arguments[0].assertString("name");
        var module = arguments[1].realNull?.assertString("module");
        return SassBoolean(_environment.globalVariableExists(
            variable.text.replaceAll("_", "-"),
            namespace: module?.text));
      }),

      BuiltInCallable("variable-exists", r"$name", (arguments) {
        var variable = arguments[0].assertString("name");
        return SassBoolean(
            _environment.variableExists(variable.text.replaceAll("_", "-")));
      }),

      BuiltInCallable("function-exists", r"$name, $module: null", (arguments) {
        var variable = arguments[0].assertString("name");
        var module = arguments[1].realNull?.assertString("module");
        return SassBoolean(_environment.functionExists(
                variable.text.replaceAll("_", "-"),
                namespace: module?.text) ||
            _builtInFunctions.containsKey(variable.text));
      }),

      BuiltInCallable("mixin-exists", r"$name, $module: null", (arguments) {
        var variable = arguments[0].assertString("name");
        var module = arguments[1].realNull?.assertString("module");
        return SassBoolean(_environment.mixinExists(
            variable.text.replaceAll("_", "-"),
            namespace: module?.text));
      }),

      BuiltInCallable("content-exists", "", (arguments) {
        if (!_environment.inMixin) {
          throw SassScriptException(
              "content-exists() may only be called within a mixin.");
        }
        return SassBoolean(_environment.content != null);
      }),

      BuiltInCallable("module-variables", r"$module", (arguments) {
        var namespace = arguments[0].assertString("module");
        var module = _environment.modules[namespace.text];
        if (module == null) {
          throw 'There is no module with namespace "${namespace.text}".';
        }

        return SassMap({
          for (var entry in module.variables.entries)
            SassString(entry.key): entry.value
        });
      }),

      BuiltInCallable("module-functions", r"$module", (arguments) {
        var namespace = arguments[0].assertString("module");
        var module = _environment.modules[namespace.text];
        if (module == null) {
          throw 'There is no module with namespace "${namespace.text}".';
        }

        return SassMap({
          for (var entry in module.functions.entries)
            SassString(entry.key): SassFunction(entry.value)
        });
      }),

      BuiltInCallable("get-function", r"$name, $css: false, $module: null",
          (arguments) {
        var name = arguments[0].assertString("name");
        var css = arguments[1].isTruthy;
        var module = arguments[2].realNull?.assertString("module");

        if (css && module != null) {
          throw r"$css and $module may not both be passed at once.";
        }

        var callable = css
            ? PlainCssCallable(name.text)
            : _addExceptionSpan(
                _callableNode,
                () => _getFunction(name.text.replaceAll("_", "-"),
                    namespace: module?.text));
        if (callable != null) return SassFunction(callable);

        throw "Function not found: $name";
      }),

      BuiltInCallable("call", r"$function, $args...", (arguments) {
        var function = arguments[0];
        var args = arguments[1] as SassArgumentList;

        var invocation = ArgumentInvocation([], {}, _callableNode.span,
            rest: ValueExpression(args, _callableNode.span),
            keywordRest: args.keywords.isEmpty
                ? null
                : ValueExpression(
                    SassMap(mapMap(args.keywords,
                        key: (String key, Value _) =>
                            SassString(key, quotes: false),
                        value: (String _, Value value) => value)),
                    _callableNode.span));

        if (function is SassString) {
          warn(
              "Passing a string to call() is deprecated and will be illegal\n"
              "in Dart Sass 2.0.0. Use call(get-function($function)) instead.",
              deprecation: true);

          var expression = FunctionExpression(
              Interpolation([function.text], _callableNode.span),
              invocation,
              _callableNode.span);
          return expression.accept(this);
        }

        var callable = function.assertFunction("function").callable;
        if (callable is Callable) {
          return _runFunctionCallable(invocation, callable, _callableNode);
        } else {
          throw SassScriptException(
              "The function ${callable.name} is asynchronous.\n"
              "This is probably caused by a bug in a Sass plugin.");
        }
      })
    ];

    var metaMixins = [
      BuiltInCallable("load-css", r"$module, $with: null", (arguments) {
        var url = Uri.parse(arguments[0].assertString("module").text);
        var withMap = arguments[1].realNull?.assertMap("with")?.contents;

        var configuration = const Configuration.empty();
        if (withMap != null) {
          var values = <String, ConfiguredValue>{};
          var span = _callableNode.span;
          withMap.forEach((variable, value) {
            var name =
                variable.assertString("with key").text.replaceAll("_", "-");
            if (values.containsKey(name)) {
              throw "The variable \$$name was configured twice.";
            }

            values[name] = ConfiguredValue(value, span);
          });
          configuration = Configuration(values);
        }

        _loadModule(url, "load-css()", _callableNode,
            (module) => _combineCss(module, clone: true).accept(this),
            baseUrl: _callableNode.span?.sourceUrl,
            configuration: configuration,
            namesInErrors: true);
        _assertConfigurationIsEmpty(configuration, nameInError: true);

        return null;
      })
    ];

    var metaModule = BuiltInModule("meta",
        functions: [...meta.global, ...metaFunctions], mixins: metaMixins);

    for (var module in [...coreModules, metaModule]) {
      _builtInModules[module.url] = module;
    }

    functions = [...?functions, ...globalFunctions, ...metaFunctions];
    for (var function in functions) {
      _builtInFunctions[function.name.replaceAll("_", "-")] = function;
    }
  }

  EvaluateResult run(Importer importer, Stylesheet node) {
    return _withWarnCallback(() {
      var url = node.span?.sourceUrl;
      if (url != null) {
        _activeModules.add(url);
        if (_asNodeSass) {
          if (url.scheme == 'file') {
            _includedFiles.add(p.fromUri(url));
          } else if (url.toString() != 'stdin') {
            _includedFiles.add(url.toString());
          }
        }
      }

      var module = _execute(importer, node);

      return EvaluateResult(_combineCss(module), _includedFiles);
    });
  }

  Value runExpression(Importer importer, Expression expression) =>
      _withWarnCallback(() => _withFakeStylesheet(
          importer, expression, () => expression.accept(this)));

  void runStatement(Importer importer, Statement statement) =>
      _withWarnCallback(() => _withFakeStylesheet(
          importer, statement, () => statement.accept(this)));

  /// Runs [callback] with a definition for the top-level `warn` function.
  T _withWarnCallback<T>(T callback()) {
    return withWarnCallback(
        (message, deprecation) => _warn(
            message, _importSpan ?? _callableNode.span,
            deprecation: deprecation),
        callback);
  }

  /// Runs [callback] with [importer] as [_importer] and a fake [_stylesheet]
  /// with [nodeForSpan]'s source span.
  T _withFakeStylesheet<T>(
      Importer importer, AstNode nodeForSpan, T callback()) {
    var oldImporter = _importer;
    _importer = importer;
    var oldStylesheet = _stylesheet;
    _stylesheet = Stylesheet(const [], nodeForSpan.span);

    try {
      return callback();
    } finally {
      _importer = oldImporter;
      _stylesheet = oldStylesheet;
    }
  }

  /// Loads the module at [url] and passes it to [callback].
  ///
  /// This first tries loading [url] relative to [baseUrl], which defaults to
  /// `_stylesheet.span.sourceUrl`.
  ///
  /// The [configuration] overrides values for `!default` variables defined in
  /// the module or modules it forwards and/or imports. If it's not passed, the
  /// current configuration is used instead. Throws a [SassRuntimeException] if
  /// a configured variable is not declared with `!default`.
  ///
  /// If [namesInErrors] is `true`, this includes the names of modules or
  /// configured variables in errors relating to them. This should only be
  /// `true` if the names won't be obvious from the source span.
  ///
  /// The [stackFrame] and [nodeForSpan] are used for the name and location of
  /// the stack frame for the duration of the [callback].
  void _loadModule(Uri url, String stackFrame, AstNode nodeForSpan,
      void callback(Module<Callable> module),
      {Uri baseUrl, Configuration configuration, bool namesInErrors = false}) {
    var builtInModule = _builtInModules[url];
    if (builtInModule != null) {
      if (configuration != null && !configuration.isImplicit) {
        throw _exception(
            namesInErrors
                ? "Built-in module $url can't be configured."
                : "Built-in modules can't be configured.",
            nodeForSpan.span);
      }

      callback(builtInModule);
      return;
    }

    _withStackFrame(stackFrame, nodeForSpan, () {
      var result =
          _loadStylesheet(url.toString(), nodeForSpan.span, baseUrl: baseUrl);
      var importer = result.item1;
      var stylesheet = result.item2;

      var canonicalUrl = stylesheet.span.sourceUrl;
      if (_activeModules.contains(canonicalUrl)) {
        throw _exception(namesInErrors
            ? "Module loop: ${p.prettyUri(canonicalUrl)} is already being "
                "loaded."
            : "Module loop: this module is already being loaded.");
      }
      _activeModules.add(canonicalUrl);

      Module<Callable> module;
      try {
        module = _execute(importer, stylesheet,
            configuration: configuration, namesInErrors: namesInErrors);
      } finally {
        _activeModules.remove(canonicalUrl);
      }

      try {
        callback(module);
      } on SassRuntimeException {
        rethrow;
      } on SassException catch (error) {
        throw _exception(error.message, error.span);
      } on SassScriptException catch (error) {
        throw _exception(error.message);
      }
    });
  }

  /// Executes [stylesheet], loaded by [importer], to produce a module.
  ///
  /// If [configuration] is not passed, the current configuration is used
  /// instead.
  ///
  /// If [namesInErrors] is `true`, this includes the names of modules in errors
  /// relating to them. This should only be `true` if the names won't be obvious
  /// from the source span.
  Module<Callable> _execute(Importer importer, Stylesheet stylesheet,
      {Configuration configuration, bool namesInErrors = false}) {
    var url = stylesheet.span.sourceUrl;

    var alreadyLoaded = _modules[url];
    if (alreadyLoaded != null) {
      if (!(configuration ?? _configuration).isImplicit) {
        throw _exception(namesInErrors
            ? "${p.prettyUri(url)} was already loaded, so it can't be "
                "configured using \"with\"."
            : "This module was already loaded, so it can't be configured using "
                "\"with\".");
      }

      return alreadyLoaded;
    }

    var environment = Environment(sourceMap: _sourceMap);
    CssStylesheet css;
    var extender = Extender();
    _withEnvironment(environment, () {
      var oldImporter = _importer;
      var oldStylesheet = _stylesheet;
      var oldRoot = _root;
      var oldParent = _parent;
      var oldEndOfImports = _endOfImports;
      var oldOutOfOrderImports = _outOfOrderImports;
      var oldExtender = _extender;
      var oldStyleRule = _styleRule;
      var oldMediaQueries = _mediaQueries;
      var oldDeclarationName = _declarationName;
      var oldInUnknownAtRule = _inUnknownAtRule;
      var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
      var oldInKeyframes = _inKeyframes;
      var oldConfiguration = _configuration;
      _importer = importer;
      _stylesheet = stylesheet;
      _root = ModifiableCssStylesheet(stylesheet.span);
      _parent = _root;
      _endOfImports = 0;
      _outOfOrderImports = null;
      _extender = extender;
      _styleRule = null;
      _mediaQueries = null;
      _declarationName = null;
      _inUnknownAtRule = false;
      _atRootExcludingStyleRule = false;
      _inKeyframes = false;
      if (configuration != null) _configuration = configuration;

      visitStylesheet(stylesheet);
      css = _outOfOrderImports == null
          ? _root
          : CssStylesheet(_addOutOfOrderImports(), stylesheet.span);

      _importer = oldImporter;
      _stylesheet = oldStylesheet;
      _root = oldRoot;
      _parent = oldParent;
      _endOfImports = oldEndOfImports;
      _outOfOrderImports = oldOutOfOrderImports;
      _extender = oldExtender;
      _styleRule = oldStyleRule;
      _mediaQueries = oldMediaQueries;
      _declarationName = oldDeclarationName;
      _inUnknownAtRule = oldInUnknownAtRule;
      _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;
      _inKeyframes = oldInKeyframes;
      _configuration = oldConfiguration;
    });

    var module = environment.toModule(css, extender);
    _modules[url] = module;
    return module;
  }

  /// Returns a copy of [_root.children] with [_outOfOrderImports] inserted
  /// after [_endOfImports], if necessary.
  List<ModifiableCssNode> _addOutOfOrderImports() {
    if (_outOfOrderImports == null) return _root.children;

    var statements = FixedLengthListBuilder<ModifiableCssNode>(
        _root.children.length + _outOfOrderImports.length)
      ..addRange(_root.children, 0, _endOfImports)
      ..addAll(_outOfOrderImports)
      ..addRange(_root.children, _endOfImports);
    return statements.build();
  }

  /// Returns a new stylesheet containing [root]'s CSS as well as the CSS of all
  /// modules transitively used by [root].
  ///
  /// This also applies each module's extensions to its upstream modules.
  ///
  /// If [clone] is `true`, this will copy the modules before extending them so
  /// that they don't modify [root] or its dependencies.
  CssStylesheet _combineCss(Module<Callable> root, {bool clone = false}) {
    if (!root.upstream.any((module) => module.transitivelyContainsCss)) {
      var selectors = root.extender.simpleSelectors;
      var unsatisfiedExtension = firstOrNull(root.extender
          .extensionsWhereTarget((target) => !selectors.contains(target)));
      if (unsatisfiedExtension != null) {
        _throwForUnsatisfiedExtension(unsatisfiedExtension);
      }

      return root.css;
    }

    var sortedModules = _topologicalModules(root);
    if (clone) {
      sortedModules = sortedModules.map((module) => module.cloneCss()).toList();
    }
    _extendModules(sortedModules);

    // The imports (and comments between them) that should be included at the
    // beginning of the final document.
    var imports = <CssNode>[];

    // The CSS statements in the final document.
    var css = <CssNode>[];

    for (var module in sortedModules.reversed) {
      var statements = module.css.children;
      var index = _indexAfterImports(statements);
      imports.addAll(statements.getRange(0, index));
      css.addAll(statements.getRange(index, statements.length));
    }

    return CssStylesheet(imports + css, root.css.span);
  }

  /// Extends the selectors in each module with the extensions defined in
  /// downstream modules.
  void _extendModules(List<Module<Callable>> sortedModules) {
    // All the extenders directly downstream of a given module (indexed by its
    // canonical URL). It's important that we create this in topological order,
    // so that by the time we're processing a module we've already filled in all
    // its downstream extenders and we can use them to extend that module.
    var downstreamExtenders = <Uri, List<Extender>>{};

    /// Extensions that haven't yet been satisfied by some upstream module. This
    /// adds extensions when they're defined but not satisfied, and removes them
    /// when they're satisfied by any module.
    var unsatisfiedExtensions = Set<Extension>.identity();

    for (var module in sortedModules) {
      // Create a snapshot of the simple selectors currently in the extender so
      // that we don't consider an extension "satisfied" below because of a
      // simple selector added by another (sibling) extension.
      var originalSelectors = module.extender.simpleSelectors.toSet();

      // Add all as-yet-unsatisfied extensions before adding downstream
      // extenders, because those are all in [unsatisfiedExtensions] already.
      unsatisfiedExtensions.addAll(module.extender.extensionsWhereTarget(
          (target) => !originalSelectors.contains(target)));

      var extenders = downstreamExtenders[module.url];
      if (extenders != null) module.extender.addExtensions(extenders);
      if (module.extender.isEmpty) continue;

      for (var upstream in module.upstream) {
        downstreamExtenders
            .putIfAbsent(upstream.url, () => [])
            .add(module.extender);
      }

      // Remove all extensions that are now satisfied after adding downstream
      // extenders so it counts any downstream extensions that have been newly
      // satisfied.
      unsatisfiedExtensions.removeAll(
          module.extender.extensionsWhereTarget(originalSelectors.contains));
    }

    if (unsatisfiedExtensions.isNotEmpty) {
      _throwForUnsatisfiedExtension(unsatisfiedExtensions.first);
    }
  }

  /// Throws an exception indicating that [extension] is unsatisfied.
  @alwaysThrows
  void _throwForUnsatisfiedExtension(Extension extension) {
    throw SassException(
        'The target selector was not found.\n'
        'Use "@extend ${extension.target} !optional" to avoid this error.',
        extension.span);
  }

  /// Returns all modules transitively used by [root] in topological order,
  /// ignoring modules that contain no CSS.
  List<Module<Callable>> _topologicalModules(Module<Callable> root) {
    // Construct a topological ordering using depth-first traversal, as in
    // https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search.
    var seen = <Module<Callable>>{};
    var sorted = QueueList<Module<Callable>>();

    void visitModule(Module<Callable> module) {
      // Each module is added to the beginning of [sorted], which means the
      // returned list contains sibling modules in the opposite order of how
      // they appear in the document. Then when the list is reversed to generate
      // the CSS, they're put back in their original order.
      for (var upstream in module.upstream) {
        if (upstream.transitivelyContainsCss && seen.add(upstream)) {
          visitModule(upstream);
        }
      }

      sorted.addFirst(module);
    }

    visitModule(root);

    return sorted;
  }

  /// Returns the index of the first node in [statements] that comes after all
  /// static imports.
  int _indexAfterImports(List<CssNode> statements) {
    var lastImport = -1;
    for (var i = 0; i < statements.length; i++) {
      var statement = statements[i];
      if (statement is CssImport) {
        lastImport = i;
      } else if (statement is! CssComment) {
        break;
      }
    }
    return lastImport + 1;
  }

  // ## Statements

  Value visitStylesheet(Stylesheet node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  Value visitAtRootRule(AtRootRule node) {
    var query = AtRootQuery.defaultQuery;
    if (node.query != null) {
      var resolved = _performInterpolation(node.query, warnForColor: true);
      query = _adjustParseError(
          node.query, () => AtRootQuery.parse(resolved, logger: _logger));
    }

    var parent = _parent;
    var included = <ModifiableCssParentNode>[];
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
  ModifiableCssParentNode _trimIncluded(List<ModifiableCssParentNode> nodes) {
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
  _ScopeCallback _scopeForAtRoot(
      AtRootRule node,
      ModifiableCssParentNode newParent,
      AtRootQuery query,
      List<ModifiableCssParentNode> included) {
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

  Value visitContentBlock(ContentBlock node) => throw UnsupportedError(
      "Evaluation handles @include and its content block together.");

  Value visitContentRule(ContentRule node) {
    var content = _environment.content;
    if (content == null) return null;

    _runUserDefinedCallable(node.arguments, content, node, () {
      for (var statement in content.declaration.children) {
        statement.accept(this);
      }
      return null;
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
      name = CssValue("$_declarationName-${name.value}", name.span);
    }
    var cssValue = node.value == null
        ? null
        : CssValue(node.value.accept(this), node.value.span);

    // If the value is an empty list, preserve it, because converting it to CSS
    // will throw an error that we want the user to see.
    if (cssValue != null &&
        (!cssValue.value.isBlank || _isEmptyList(cssValue.value))) {
      _parent.addChild(ModifiableCssDeclaration(name, cssValue, node.span,
          valueSpanForMap: _expressionNode(node.value)?.span));
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
    var nodeForSpan = _expressionNode(node.list);
    var setVariables = node.variables.length == 1
        ? (Value value) => _environment.setLocalVariable(
            node.variables.first, value.withoutSlash(), nodeForSpan)
        : (Value value) =>
            _setMultipleVariables(node.variables, value, nodeForSpan);
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
      List<String> variables, Value value, AstNode nodeForSpan) {
    var list = value.asList;
    var minLength = math.min(variables.length, list.length);
    for (var i = 0; i < minLength; i++) {
      _environment.setLocalVariable(
          variables[i], list[i].withoutSlash(), nodeForSpan);
    }
    for (var i = minLength; i < variables.length; i++) {
      _environment.setLocalVariable(variables[i], sassNull, nodeForSpan);
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
        targetText,
        () => SelectorList.parse(
            trimAscii(targetText.value, excludeEscape: true),
            logger: _logger,
            allowParent: false));

    for (var complex in list.components) {
      if (complex.components.length != 1 ||
          complex.components.first is! CompoundSelector) {
        // If the selector was a compound selector but not a simple
        // selector, emit a more explicit error.
        throw SassFormatException(
            "complex selectors may not be extended.", targetText.span);
      }

      var compound = complex.components.first as CompoundSelector;
      if (compound.components.length != 1) {
        throw SassFormatException(
            "compound selectors may no longer be extended.\n"
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
    // NOTE: this logic is largely duplicated in [visitCssAtRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "At-rules may not be used within nested declarations.", node.span);
    }

    var name = _interpolationToValue(node.name);

    var value = node.value == null
        ? null
        : _interpolationToValue(node.value, trim: true, warnForColor: true);

    if (node.children == null) {
      _parent.addChild(
          ModifiableCssAtRule(name, node.span, childless: true, value: value));
      return null;
    }

    var wasInKeyframes = _inKeyframes;
    var wasInUnknownAtRule = _inUnknownAtRule;
    if (unvendor(name.value) == 'keyframes') {
      _inKeyframes = true;
    } else {
      _inUnknownAtRule = true;
    }

    _withParent(ModifiableCssAtRule(name, node.span, value: value), () {
      if (!_inStyleRule || _inKeyframes) {
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
        node.from, () => node.from.accept(this).assertNumber());
    var toNumber =
        _addExceptionSpan(node.to, () => node.to.accept(this).assertNumber());

    var from = _addExceptionSpan(
        node.from,
        () => fromNumber
            .coerce(toNumber.numeratorUnits, toNumber.denominatorUnits)
            .assertInt());
    var to = _addExceptionSpan(node.to, () => toNumber.assertInt());

    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return null;

    return _environment.scope(() {
      var nodeForSpan = _expressionNode(node.from);
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(
            node.variable, SassNumber(i), nodeForSpan);
        var result = _handleReturn<Statement>(
            node.children, (child) => child.accept(this));
        if (result != null) return result;
      }
      return null;
    }, semiGlobal: true);
  }

  Value visitForwardRule(ForwardRule node) {
    var oldConfiguration = _configuration;
    var adjustedConfiguration = oldConfiguration.throughForward(node);

    if (node.configuration.isNotEmpty) {
      var newConfiguration =
          _addForwardConfiguration(adjustedConfiguration, node);

      _loadModule(node.url, "@forward", node, (module) {
        _environment.forwardModule(module, node);
      }, configuration: newConfiguration);

      _removeUsedConfiguration(adjustedConfiguration, newConfiguration,
          except: node.configuration.isEmpty
              ? const {}
              : {
                  for (var variable in node.configuration)
                    if (!variable.isGuarded) variable.name
                });

      _assertConfigurationIsEmpty(newConfiguration,
          only: {for (var variable in node.configuration) variable.name});
    } else {
      _configuration = adjustedConfiguration;
      _loadModule(node.url, "@forward", node, (module) {
        _environment.forwardModule(module, node);
      });
      _configuration = oldConfiguration;
    }

    return null;
  }

  /// Updates [configuration] to include [node]'s configuration and return the
  /// result.
  Configuration _addForwardConfiguration(
      Configuration configuration, ForwardRule node) {
    var newValues = Map.of(configuration.values);
    for (var variable in node.configuration) {
      if (variable.isGuarded) {
        var oldValue = configuration.remove(variable.name);
        if (oldValue != null && oldValue.value != sassNull) {
          newValues[variable.name] = oldValue;
          continue;
        }
      }

      newValues[variable.name] = ConfiguredValue(
          variable.expression.accept(this).withoutSlash(),
          variable.span,
          _expressionNode(variable.expression));
    }

    return Configuration(newValues);
  }

  /// Remove configured values from [upstream] that have been removed from
  /// [downstream], unless they match a name in [except].
  void _removeUsedConfiguration(
      Configuration upstream, Configuration downstream,
      {@required Set<String> except}) {
    for (var name in upstream.values.keys.toList()) {
      if (except.contains(name)) continue;
      if (!downstream.values.containsKey(name)) upstream.remove(name);
    }
  }

  /// Throws an error if [configuration] contains any values.
  ///
  /// If [only] is passed, this will only throw an error for configured values
  /// with the given names.
  ///
  /// If [nameInError] is `true`, this includes the name of the configured
  /// variable in the error message. This should only be `true` if the name
  /// won't be obvious from the source span.
  void _assertConfigurationIsEmpty(Configuration configuration,
      {Set<String> only, bool nameInError = false}) {
    configuration.values.forEach((name, value) {
      if (only != null && !only.contains(name)) return;

      throw _exception(
          nameInError
              ? "\$$name was not declared with !default in the @used module."
              : "This variable was not declared with !default in the @used "
                  "module.",
          value.configurationSpan);
    });
  }

  Value visitFunctionRule(FunctionRule node) {
    _environment.setFunction(UserDefinedCallable(node, _environment.closure()));
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
    return _withStackFrame("@import", import, () {
      var result = _loadStylesheet(import.url, import.span, forImport: true);
      var importer = result.item1;
      var stylesheet = result.item2;

      var url = stylesheet.span.sourceUrl;
      if (!_activeModules.add(url)) {
        throw _exception("This file is already being loaded.");
      }

      _activeModules.add(url);

      // If the imported stylesheet doesn't use any modules, we can inject its
      // CSS directly into the current stylesheet. If it does use modules, we
      // need to put its CSS into an intermediate [ModifiableCssStylesheet] so
      // that we can hermetically resolve `@extend`s before injecting it.
      if (stylesheet.uses.isEmpty && stylesheet.forwards.isEmpty) {
        var oldImporter = _importer;
        var oldStylesheet = _stylesheet;
        _importer = importer;
        _stylesheet = stylesheet;
        visitStylesheet(stylesheet);
        _importer = oldImporter;
        _stylesheet = oldStylesheet;
        _activeModules.remove(url);
        return;
      }

      List<ModifiableCssNode> children;
      var environment = _environment.global();
      _withEnvironment(environment, () {
        var oldImporter = _importer;
        var oldStylesheet = _stylesheet;
        var oldRoot = _root;
        var oldParent = _parent;
        var oldEndOfImports = _endOfImports;
        var oldOutOfOrderImports = _outOfOrderImports;
        var oldConfiguration = _configuration;
        _importer = importer;
        _stylesheet = stylesheet;
        _root = ModifiableCssStylesheet(stylesheet.span);
        _parent = _root;
        _endOfImports = 0;
        _outOfOrderImports = null;

        // This configuration is only used if it passes through a `@forward`
        // rule, so we avoid creating unnecessary ones for performance reasons.
        if (stylesheet.forwards.isNotEmpty) {
          _configuration = environment.toImplicitConfiguration();
        }

        visitStylesheet(stylesheet);
        children = _addOutOfOrderImports();

        _importer = oldImporter;
        _stylesheet = oldStylesheet;
        _root = oldRoot;
        _parent = oldParent;
        _endOfImports = oldEndOfImports;
        _outOfOrderImports = oldOutOfOrderImports;
        _configuration = oldConfiguration;
      });

      // Create a dummy module with empty CSS and no extensions to make forwarded
      // members available in the current import context and to combine all the
      // CSS from modules used by [stylesheet].
      var module = environment.toModule(
          CssStylesheet(const [], stylesheet.span), Extender.empty);
      _environment.importForwards(module);

      if (module.transitivelyContainsCss) {
        // If any transitively used module contains extensions, we need to clone
        // all modules' CSS. Otherwise, it's possible that they'll be used or
        // imported from another location that shouldn't have the same extensions
        // applied.
        _combineCss(module, clone: module.transitivelyContainsExtensions)
            .accept(this);
      }

      var visitor = _ImportedCssVisitor(this);
      for (var child in children) {
        child.accept(visitor);
      }

      _activeModules.remove(url);
    });
  }

  /// Loads the [Stylesheet] identified by [url], or throws a
  /// [SassRuntimeException] if loading fails.
  ///
  /// This first tries loading [url] relative to [baseUrl], which defaults to
  /// `_stylesheet.span.sourceUrl`.
  Tuple2<Importer, Stylesheet> _loadStylesheet(String url, FileSpan span,
      {Uri baseUrl, bool forImport = false}) {
    try {
      assert(_importSpan == null);
      _importSpan = span;

      if (_nodeImporter != null) {
        var stylesheet = _importLikeNode(url, forImport);
        if (stylesheet != null) return Tuple2(null, stylesheet);
      } else {
        var tuple = _importCache.import(Uri.parse(url),
            baseImporter: _importer,
            baseUrl: baseUrl ?? _stylesheet?.span?.sourceUrl,
            forImport: forImport);
        if (tuple != null) return tuple;
      }

      if (url.startsWith('package:') && isNode) {
        // Special-case this error message, since it's tripped people up in the
        // past.
        throw "\"package:\" URLs aren't supported on this platform.";
      } else {
        throw "Can't find stylesheet to import.";
      }
    } on SassException catch (error) {
      throw _exception(error.message, error.span);
    } catch (error) {
      String message;
      try {
        message = error.message as String;
      } catch (_) {
        message = error.toString();
      }
      throw _exception(message);
    } finally {
      _importSpan = null;
    }
  }

  /// Imports a stylesheet using [_nodeImporter].
  ///
  /// Returns the [Stylesheet], or `null` if the import failed.
  Stylesheet _importLikeNode(String originalUrl, bool forImport) {
    var result =
        _nodeImporter.load(originalUrl, _stylesheet.span?.sourceUrl, forImport);
    if (result == null) return null;

    var contents = result.item1;
    var url = result.item2;

    _includedFiles.add(url.startsWith('file:') ? p.fromUri(url) : url);

    return Stylesheet.parse(
        contents, url.startsWith('file') ? Syntax.forPath(url) : Syntax.scss,
        url: url, logger: _logger);
  }

  /// Adds a CSS import for [import].
  void _visitStaticImport(StaticImport import) {
    // NOTE: this logic is largely duplicated in [visitCssImport]. Most changes
    // here should be mirrored there.

    var url = _interpolationToValue(import.url);
    var supports = import.supports;
    var resolvedSupports = supports is SupportsDeclaration
        ? "${_evaluateToCss(supports.name)}: "
            "${_evaluateToCss(supports.value)}"
        : (supports == null ? null : _visitSupportsCondition(supports));
    var mediaQuery =
        import.media == null ? null : _visitMediaQueries(import.media);

    var node = ModifiableCssImport(url, import.span,
        supports: resolvedSupports == null
            ? null
            : CssValue("supports($resolvedSupports)", import.supports.span),
        media: mediaQuery);

    if (_parent != _root) {
      _parent.addChild(node);
    } else if (_endOfImports == _root.children.length) {
      _root.addChild(node);
      _endOfImports++;
    } else {
      _outOfOrderImports ??= [];
      _outOfOrderImports.add(node);
    }
    return null;
  }

  Value visitIncludeRule(IncludeRule node) {
    var mixin = _addExceptionSpan(node,
        () => _environment.getMixin(node.name, namespace: node.namespace));
    if (mixin == null) {
      throw _exception("Undefined mixin.", node.span);
    }

    if (mixin is BuiltInCallable) {
      if (node.content != null) {
        throw _exception("Mixin doesn't accept a content block.", node.span);
      }

      _runBuiltInCallable(node.arguments, mixin, node);
    } else if (mixin is UserDefinedCallable<Environment>) {
      if (node.content != null &&
          !(mixin.declaration as MixinRule).hasContent) {
        throw _exception("Mixin doesn't accept a content block.", node.span);
      }

      var contentCallable = node.content == null
          ? null
          : UserDefinedCallable(node.content, _environment.closure());

      _runUserDefinedCallable(node.arguments, mixin, node, () {
        _environment.withContent(contentCallable, () {
          _environment.asMixin(() {
            for (var statement in mixin.declaration.children) {
              _addErrorSpan(node, () => statement.accept(this));
            }
          });
          return null;
        });
        return null;
      });
    } else {
      throw UnsupportedError("Unknown callable type $mixin.");
    }

    return null;
  }

  Value visitMixinRule(MixinRule node) {
    _environment.setMixin(UserDefinedCallable(node, _environment.closure()));
    return null;
  }

  Value visitLoudComment(LoudComment node) {
    // NOTE: this logic is largely duplicated in [visitCssComment]. Most changes
    // here should be mirrored there.

    if (_inFunction) return null;

    // Comments are allowed to appear between CSS imports.
    if (_parent == _root && _endOfImports == _root.children.length) {
      _endOfImports++;
    }

    _parent.addChild(
        ModifiableCssComment(_performInterpolation(node.text), node.span));
    return null;
  }

  Value visitMediaRule(MediaRule node) {
    // NOTE: this logic is largely duplicated in [visitCssMediaRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var queries = _visitMediaQueries(node.query);
    var mergedQueries = _mediaQueries == null
        ? null
        : _mergeMediaQueries(_mediaQueries, queries);
    if (mergedQueries != null && mergedQueries.isEmpty) return null;

    _withParent(ModifiableCssMediaRule(mergedQueries ?? queries, node.span),
        () {
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
    return _adjustParseError<List<CssMediaQuery>>(interpolation,
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
    // NOTE: this logic is largely duplicated in [visitCssStyleRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var selectorText =
        _interpolationToValue(node.selector, trim: true, warnForColor: true);
    if (_inKeyframes) {
      // NOTE: this logic is largely duplicated in [visitCssKeyframeBlock]. Most
      // changes here should be mirrored there.

      var parsedSelector = _adjustParseError(
          node.selector,
          () => KeyframeSelectorParser(selectorText.value, logger: _logger)
              .parse());
      var rule = ModifiableCssKeyframeBlock(
          CssValue(List.unmodifiable(parsedSelector), node.selector.span),
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
        node.selector,
        () => SelectorList.parse(selectorText.value,
            allowParent: !_stylesheet.plainCss,
            allowPlaceholder: !_stylesheet.plainCss,
            logger: _logger));
    parsedSelector = _addExceptionSpan(
        node.selector,
        () => parsedSelector.resolveParentSelectors(
            _styleRule?.originalSelector,
            implicitParent: !_atRootExcludingStyleRule));

    var selector = _extender.addSelector(
        parsedSelector, node.selector.span, _mediaQueries);
    var rule = ModifiableCssStyleRule(selector, node.span,
        originalSelector: parsedSelector);
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
    // NOTE: this logic is largely duplicated in [visitCssSupportsRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Supports rules may not be used within nested declarations.",
          node.span);
    }

    var condition =
        CssValue(_visitSupportsCondition(node.condition), node.condition.span);
    _withParent(ModifiableCssSupportsRule(condition, node.span), () {
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
      if (node.namespace == null && _environment.atRoot) {
        var override = _configuration.remove(node.name);
        if (override != null) {
          _addExceptionSpan(node, () {
            _environment.setVariable(
                node.name, override.value, override.assignmentNode,
                global: true);
          });
          return null;
        }
      }

      var value = _addExceptionSpan(node,
          () => _environment.getVariable(node.name, namespace: node.namespace));
      if (value != null && value != sassNull) return null;
    }

    if (node.isGlobal && !_environment.globalVariableExists(node.name)) {
      _logger.warn(
          _environment.atRoot
              ? "As of Dart Sass 2.0.0, !global assignments won't be able to\n"
                  "declare new variables. Since this assignment is at the root "
                  "of the stylesheet,\n"
                  "the !global flag is unnecessary and can safely be removed."
              : "As of Dart Sass 2.0.0, !global assignments won't be able to\n"
                  "declare new variables. Consider adding "
                  "`${node.originalName}: null` at the root of the\n"
                  "stylesheet.",
          span: node.span,
          trace: _stackTrace(node.span),
          deprecation: true);
    }

    var value = node.expression.accept(this).withoutSlash();
    _addExceptionSpan(node, () {
      _environment.setVariable(
          node.name, value, _expressionNode(node.expression),
          namespace: node.namespace, global: node.isGlobal);
    });
    return null;
  }

  Value visitUseRule(UseRule node) {
    var configuration = node.configuration.isEmpty
        ? const Configuration.empty()
        : Configuration({
            for (var variable in node.configuration)
              variable.name: ConfiguredValue(
                  variable.expression.accept(this).withoutSlash(),
                  variable.span,
                  _expressionNode(variable.expression))
          });

    _loadModule(node.url, "@use", node, (module) {
      _environment.addModule(module, namespace: node.namespace);
    }, configuration: configuration);
    _assertConfigurationIsEmpty(configuration);

    return null;
  }

  Value visitWarnRule(WarnRule node) {
    var value = _addExceptionSpan(node, () => node.expression.accept(this));
    _logger.warn(
        value is SassString ? value.text : _serialize(value, node.expression),
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
    return _addExceptionSpan(node, () {
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
          return SassBoolean(left == right);

        case BinaryOperator.notEquals:
          var right = node.right.accept(this);
          return SassBoolean(left != right);

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
            return (result as SassNumber).withSlash(left, right);
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
    var result = _addExceptionSpan(node,
        () => _environment.getVariable(node.name, namespace: node.namespace));
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
        throw StateError("Unknown unary operator ${node.operator}.");
    }
  }

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      SassBoolean(node.value);

  Value visitIfExpression(IfExpression node) {
    var pair = _evaluateMacroArguments(node);
    var positional = pair.item1;
    var named = pair.item2;

    _verifyArguments(positional.length, named, IfExpression.declaration, node);

    // ignore: prefer_is_empty
    var condition = positional.length > 0 ? positional[0] : named["condition"];
    var ifTrue = positional.length > 1 ? positional[1] : named["if-true"];
    var ifFalse = positional.length > 2 ? positional[2] : named["if-false"];

    return (condition.accept(this).isTruthy ? ifTrue : ifFalse).accept(this);
  }

  SassNull visitNullExpression(NullExpression node) => sassNull;

  SassNumber visitNumberExpression(NumberExpression node) =>
      SassNumber(node.value, node.unit);

  Value visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  SassColor visitColorExpression(ColorExpression node) => node.value;

  SassList visitListExpression(ListExpression node) => SassList(
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
    return SassMap(map);
  }

  Value visitFunctionExpression(FunctionExpression node) {
    var plainName = node.name.asPlain;
    Callable function;
    if (plainName != null) {
      function = _addExceptionSpan(
          node,
          () => _getFunction(
              // If the node has a namespace, the plain name was already
              // normalized at parse-time so we don't need to renormalize here.
              node.namespace == null
                  ? plainName.replaceAll("_", "-")
                  : plainName,
              namespace: node.namespace));
    }

    if (function == null) {
      if (node.namespace != null) {
        throw _exception("Undefined function.", node.span);
      }

      function = PlainCssCallable(_performInterpolation(node.name));
    }

    var oldInFunction = _inFunction;
    _inFunction = true;
    var result = _addErrorSpan(
        node, () => _runFunctionCallable(node.arguments, function, node));
    _inFunction = oldInFunction;
    return result;
  }

  /// Like `_environment.getFunction`, but also returns built-in
  /// globally-available functions.
  Callable _getFunction(String name, {String namespace}) {
    var local = _environment.getFunction(name, namespace: namespace);
    if (local != null || namespace != null) return local;
    return _builtInFunctions[name];
  }

  /// Evaluates the arguments in [arguments] as applied to [callable], and
  /// invokes [run] in a scope with those arguments defined.
  Value _runUserDefinedCallable(
      ArgumentInvocation arguments,
      UserDefinedCallable<Environment> callable,
      AstNode nodeWithSpan,
      Value run()) {
    var evaluated = _evaluateArguments(arguments);

    var name = callable.name == null ? "@content" : callable.name + "()";
    return _withStackFrame(name, nodeWithSpan, () {
      // Add an extra closure() call so that modifications to the environment
      // don't affect the underlying environment closure.
      return _withEnvironment(callable.environment.closure(), () {
        return _environment.scope(() {
          _verifyArguments(evaluated.positional.length, evaluated.named,
              callable.declaration.arguments, nodeWithSpan);

          var declaredArguments = callable.declaration.arguments.arguments;
          var minLength =
              math.min(evaluated.positional.length, declaredArguments.length);
          for (var i = 0; i < minLength; i++) {
            _environment.setLocalVariable(
                declaredArguments[i].name,
                evaluated.positional[i].withoutSlash(),
                _sourceMap ? evaluated.positionalNodes[i] : null);
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
                    ? evaluated.namedNodes[argument.name] ??
                        _expressionNode(argument.defaultValue)
                    : null);
          }

          SassArgumentList argumentList;
          if (callable.declaration.arguments.restArgument != null) {
            var rest = evaluated.positional.length > declaredArguments.length
                ? evaluated.positional.sublist(declaredArguments.length)
                : const <Value>[];
            argumentList = SassArgumentList(
                rest,
                evaluated.named,
                evaluated.separator == ListSeparator.undecided
                    ? ListSeparator.comma
                    : evaluated.separator);
            _environment.setLocalVariable(
                callable.declaration.arguments.restArgument,
                argumentList,
                nodeWithSpan);
          }

          var result = run();

          if (argumentList == null) return result;
          if (evaluated.named.isEmpty) return result;
          if (argumentList.wereKeywordsAccessed) return result;

          var argumentWord = pluralize('argument', evaluated.named.keys.length);
          var argumentNames =
              toSentence(evaluated.named.keys.map((name) => "\$$name"), 'or');
          throw _exception(
              "No $argumentWord named $argumentNames.", nodeWithSpan.span);
        });
      });
    });
  }

  /// Evaluates [arguments] as applied to [callable].
  Value _runFunctionCallable(
      ArgumentInvocation arguments, Callable callable, AstNode nodeWithSpan) {
    if (callable is BuiltInCallable) {
      var result = _runBuiltInCallable(arguments, callable, nodeWithSpan);
      if (result == null) {
        throw _exception(
            "Custom functions may not return Dart's null.", nodeWithSpan.span);
      }

      return result.withoutSlash();
    } else if (callable is UserDefinedCallable<Environment>) {
      return _runUserDefinedCallable(arguments, callable, nodeWithSpan, () {
        for (var statement in callable.declaration.children) {
          var returnValue = statement.accept(this);
          if (returnValue is Value) return returnValue;
        }

        throw _exception(
            "Function finished without @return.", callable.declaration.span);
      }).withoutSlash();
    } else if (callable is PlainCssCallable) {
      if (arguments.named.isNotEmpty || arguments.keywordRest != null) {
        throw _exception("Plain CSS functions don't support keyword arguments.",
            nodeWithSpan.span);
      }

      var buffer = StringBuffer("${callable.name}(");
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
        buffer.write(_serialize(rest, arguments.rest));
      }
      buffer.writeCharCode($rparen);

      return SassString(buffer.toString(), quotes: false);
    } else {
      return null;
    }
  }

  /// Evaluates [invocation] as applied to [callable], and invokes [callable]'s
  /// body.
  Value _runBuiltInCallable(ArgumentInvocation arguments,
      BuiltInCallable callable, AstNode nodeWithSpan) {
    var evaluated = _evaluateArguments(arguments, trackSpans: false);

    var oldCallableNode = _callableNode;
    _callableNode = nodeWithSpan;

    var namedSet = MapKeySet(evaluated.named);
    var tuple = callable.callbackFor(evaluated.positional.length, namedSet);
    var overload = tuple.item1;
    var callback = tuple.item2;
    _addExceptionSpan(nodeWithSpan,
        () => overload.verify(evaluated.positional.length, namedSet));

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

      argumentList = SassArgumentList(
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
    } on SassRuntimeException {
      rethrow;
    } catch (error) {
      String message;
      try {
        message = error.message as String;
      } catch (_) {
        message = error.toString();
      }
      throw _exception(message, nodeWithSpan.span);
    }
    _callableNode = oldCallableNode;

    if (argumentList == null) return result;
    if (evaluated.named.isEmpty) return result;
    if (argumentList.wereKeywordsAccessed) return result;
    throw _exception(
        "No ${pluralize('argument', evaluated.named.keys.length)} named "
        "${toSentence(evaluated.named.keys.map((name) => "\$$name"), 'or')}.",
        nodeWithSpan.span);
  }

  /// Returns the evaluated values of the given [arguments].
  ///
  /// If [trackSpans] is `true`, this tracks the source spans of the arguments
  /// being passed in. It defaults to [_sourceMap].
  _ArgumentResults _evaluateArguments(ArgumentInvocation arguments,
      {bool trackSpans}) {
    trackSpans ??= _sourceMap;

    var positional = [
      for (var expression in arguments.positional) expression.accept(this)
    ];
    var named = mapMap<String, Expression, String, Value>(arguments.named,
        value: (_, expression) => expression.accept(this));

    var positionalNodes = trackSpans
        ? [
            for (var expression in arguments.positional)
              _expressionNode(expression)
          ]
        : null;
    var namedNodes = trackSpans
        ? mapMap<String, Expression, String, AstNode>(arguments.named,
            value: (_, expression) => _expressionNode(expression))
        : null;

    if (arguments.rest == null) {
      return _ArgumentResults(positional, named, ListSeparator.undecided,
          positionalNodes: positionalNodes, namedNodes: namedNodes);
    }

    var rest = arguments.rest.accept(this);
    var restNodeForSpan = trackSpans ? _expressionNode(arguments.rest) : null;
    var separator = ListSeparator.undecided;
    if (rest is SassMap) {
      _addRestMap(named, rest, arguments.rest);
      namedNodes?.addAll({
        for (var key in rest.contents.keys)
          (key as SassString).text: restNodeForSpan
      });
    } else if (rest is SassList) {
      positional.addAll(rest.asList);
      positionalNodes?.addAll(List.filled(rest.lengthAsList, restNodeForSpan));
      separator = rest.separator;

      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = value;
          if (namedNodes != null) namedNodes[key] = restNodeForSpan;
        });
      }
    } else {
      positional.add(rest);
      positionalNodes?.add(restNodeForSpan);
    }

    if (arguments.keywordRest == null) {
      return _ArgumentResults(positional, named, separator,
          positionalNodes: positionalNodes, namedNodes: namedNodes);
    }

    var keywordRest = arguments.keywordRest.accept(this);
    var keywordRestNodeForSpan =
        trackSpans ? _expressionNode(arguments.keywordRest) : null;
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, arguments.keywordRest);
      namedNodes?.addAll({
        for (var key in keywordRest.contents.keys)
          (key as SassString).text: keywordRestNodeForSpan
      });
      return _ArgumentResults(positional, named, separator,
          positionalNodes: positionalNodes, namedNodes: namedNodes);
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
      return Tuple2(
          invocation.arguments.positional, invocation.arguments.named);
    }

    var positional = invocation.arguments.positional.toList();
    var named = Map.of(invocation.arguments.named);
    var rest = invocation.arguments.rest.accept(this);
    if (rest is SassMap) {
      _addRestMap(named, rest, invocation, (value) => ValueExpression(value));
    } else if (rest is SassList) {
      positional.addAll(rest.asList.map((value) => ValueExpression(value)));
      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = ValueExpression(value);
        });
      }
    } else {
      positional.add(ValueExpression(rest));
    }

    if (invocation.arguments.keywordRest == null) {
      return Tuple2(positional, named);
    }

    var keywordRest = invocation.arguments.keywordRest.accept(this);
    if (keywordRest is SassMap) {
      _addRestMap(
          named, keywordRest, invocation, (value) => ValueExpression(value));
      return Tuple2(positional, named);
    } else {
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).",
          invocation.span);
    }
  }

  /// Adds the values in [map] to [values].
  ///
  /// Throws a [SassRuntimeException] associated with [nodeForSpan]'s source
  /// span if any [map] keys aren't strings.
  ///
  /// If [convert] is passed, that's used to convert the map values to the value
  /// type for [values]. Otherwise, the [Value]s are used as-is.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  void _addRestMap<T>(Map<String, T> values, SassMap map, AstNode nodeForSpan,
      [T convert(Value value)]) {
    convert ??= (value) => value as T;
    map.contents.forEach((key, value) {
      if (key is SassString) {
        values[key.text] = convert(value);
      } else {
        throw _exception(
            "Variable keyword argument map must have string keys.\n"
            "$key is not a string in $map.",
            nodeForSpan.span);
      }
    });
  }

  /// Throws a [SassRuntimeException] if [positional] and [named] aren't valid
  /// when applied to [arguments].
  void _verifyArguments(int positional, Map<String, dynamic> named,
          ArgumentDeclaration arguments, AstNode nodeWithSpan) =>
      _addExceptionSpan(
          nodeWithSpan, () => arguments.verify(positional, MapKeySet(named)));

  Value visitSelectorExpression(SelectorExpression node) {
    if (_styleRule == null) return sassNull;
    return _styleRule.originalSelector.asSassList;
  }

  SassString visitStringExpression(StringExpression node) {
    // Don't use [performInterpolation] here because we need to get the raw text
    // from strings, rather than the semantic value.
    return SassString(
        node.text.contents.map((value) {
          if (value is String) return value;
          var expression = value as Expression;
          var result = expression.accept(this);
          return result is SassString
              ? result.text
              : _serialize(result, expression, quote: false);
        }).join(),
        quotes: node.hasQuotes);
  }

  // ## Plain CSS

  // These methods are used when evaluating CSS syntax trees from `@import`ed
  // stylesheets that themselves contain `@use` rules, and CSS included via the
  // `load-css()` function. When we load a module using one of these constructs,
  // we first convert it to CSS (we can't evaluate it as Sass directly because
  // it may be used elsewhere and it must only be evaluatedonce). Then we
  // execute that CSS more or less as though it were Sass (we can't inject it
  // into the stylesheet as-is because the `@import` may be nested in other
  // rules). That's what these rules implement.

  void visitCssAtRule(CssAtRule node) {
    // NOTE: this logic is largely duplicated in [visitAtRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "At-rules may not be used within nested declarations.", node.span);
    }

    if (node.isChildless) {
      _parent.addChild(ModifiableCssAtRule(node.name, node.span,
          childless: true, value: node.value));
      return null;
    }

    var wasInKeyframes = _inKeyframes;
    var wasInUnknownAtRule = _inUnknownAtRule;
    if (unvendor(node.name.value) == 'keyframes') {
      _inKeyframes = true;
    } else {
      _inUnknownAtRule = true;
    }

    _withParent(ModifiableCssAtRule(node.name, node.span, value: node.value),
        () {
      // We don't have to check for an unknown at-rule in a style rule here,
      // because the previous compilation has already bubbled the at-rule to the
      // root.
      for (var child in node.children) {
        child.accept(this);
      }
    }, through: (node) => node is CssStyleRule, scopeWhen: false);

    _inUnknownAtRule = wasInUnknownAtRule;
    _inKeyframes = wasInKeyframes;
  }

  void visitCssComment(CssComment node) {
    // NOTE: this logic is largely duplicated in [visitLoudComment]. Most
    // changes here should be mirrored there.

    // Comments are allowed to appear between CSS imports.
    if (_parent == _root && _endOfImports == _root.children.length) {
      _endOfImports++;
    }

    _parent.addChild(ModifiableCssComment(node.text, node.span));
  }

  void visitCssDeclaration(CssDeclaration node) {
    _parent.addChild(ModifiableCssDeclaration(node.name, node.value, node.span,
        valueSpanForMap: node.valueSpanForMap));
  }

  void visitCssImport(CssImport node) {
    // NOTE: this logic is largely duplicated in [_visitStaticImport]. Most
    // changes here should be mirrored there.

    var modifiableNode = ModifiableCssImport(node.url, node.span,
        supports: node.supports, media: node.media);
    if (_parent != _root) {
      _parent.addChild(modifiableNode);
    } else if (_endOfImports == _root.children.length) {
      _root.addChild(modifiableNode);
      _endOfImports++;
    } else {
      _outOfOrderImports ??= [];
      _outOfOrderImports.add(modifiableNode);
    }
  }

  void visitCssKeyframeBlock(CssKeyframeBlock node) {
    // NOTE: this logic is largely duplicated in [visitStyleRule]. Most changes
    // here should be mirrored there.

    var rule = ModifiableCssKeyframeBlock(node.selector, node.span);
    _withParent(rule, () {
      for (var child in node.children) {
        child.accept(this);
      }
    }, through: (node) => node is CssStyleRule, scopeWhen: false);
  }

  void visitCssMediaRule(CssMediaRule node) {
    // NOTE: this logic is largely duplicated in [visitMediaRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var mergedQueries = _mediaQueries == null
        ? null
        : _mergeMediaQueries(_mediaQueries, node.queries);
    if (mergedQueries != null && mergedQueries.isEmpty) return null;

    _withParent(
        ModifiableCssMediaRule(mergedQueries ?? node.queries, node.span), () {
      _withMediaQueries(mergedQueries ?? node.queries, () {
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
        scopeWhen: false);
  }

  void visitCssStyleRule(CssStyleRule node) {
    // NOTE: this logic is largely duplicated in [visitStyleRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var originalSelector = node.selector.value.resolveParentSelectors(
        _styleRule?.originalSelector,
        implicitParent: !_atRootExcludingStyleRule);
    var selector = _extender.addSelector(
        originalSelector, node.selector.span, _mediaQueries);
    var rule = ModifiableCssStyleRule(selector, node.span,
        originalSelector: originalSelector);
    var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
    _atRootExcludingStyleRule = false;
    _withParent(rule, () {
      _withStyleRule(rule, () {
        for (var child in node.children) {
          child.accept(this);
        }
      });
    }, through: (node) => node is CssStyleRule, scopeWhen: false);
    _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;

    if (!_inStyleRule && _parent.children.isNotEmpty) {
      var lastChild = _parent.children.last;
      lastChild.isGroupEnd = true;
    }
  }

  void visitCssStylesheet(CssStylesheet node) {
    for (var statement in node.children) {
      statement.accept(this);
    }
  }

  void visitCssSupportsRule(CssSupportsRule node) {
    // NOTE: this logic is largely duplicated in [visitSupportsRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Supports rules may not be used within nested declarations.",
          node.span);
    }

    _withParent(ModifiableCssSupportsRule(node.condition, node.span), () {
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
    }, through: (node) => node is CssStyleRule, scopeWhen: false);
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
      {bool trim = false, bool warnForColor = false}) {
    var result =
        _performInterpolation(interpolation, warnForColor: warnForColor);
    return CssValue(trim ? trimAscii(result, excludeEscape: true) : result,
        interpolation.span);
  }

  /// Evaluates [interpolation].
  ///
  /// If [warnForColor] is `true`, this will emit a warning for any named color
  /// values passed into the interpolation.
  String _performInterpolation(Interpolation interpolation,
      {bool warnForColor = false}) {
    return interpolation.contents.map((value) {
      if (value is String) return value;
      var expression = value as Expression;
      var result = expression.accept(this);

      if (warnForColor &&
          result is SassColor &&
          namesByColor.containsKey(result)) {
        var alternative = BinaryOperationExpression(
            BinaryOperator.plus,
            StringExpression(Interpolation([""], null), quotes: true),
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

      return _serialize(result, expression, quote: false);
    }).join();
  }

  /// Evaluates [expression] and calls `toCssString()` and wraps a
  /// [SassScriptException] to associate it with [span].
  String _evaluateToCss(Expression expression, {bool quote = true}) =>
      _serialize(expression.accept(this), expression, quote: quote);

  /// Calls `value.toCssString()` and wraps a [SassScriptException] to associate
  /// it with [nodeWithSpan]'s source span.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  String _serialize(Value value, AstNode nodeWithSpan, {bool quote = true}) =>
      _addExceptionSpan(nodeWithSpan, () => value.toCssString(quote: quote));

  /// Returns the [AstNode] whose span should be used for [expression].
  ///
  /// If [expression] is a variable reference, [AstNode]'s span will be the span
  /// where that variable was originally declared. Otherwise, this will just
  /// return [expression].
  ///
  /// Returns `null` if [_sourceMap] is `false`.
  ///
  /// This returns an [AstNode] rather than a [FileSpan] so we can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  AstNode _expressionNode(Expression expression) {
    if (!_sourceMap) return null;
    if (expression is VariableExpression) {
      return _environment.getVariableNode(expression.name,
          namespace: expression.namespace);
    } else {
      return expression;
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
  T _withParent<S extends ModifiableCssParentNode, T>(S node, T callback(),
      {bool through(CssNode node), bool scopeWhen = true}) {
    _addChild(node, through: through);

    var oldParent = _parent;
    _parent = node;
    var result = _environment.scope(callback, when: scopeWhen);
    _parent = oldParent;

    return result;
  }

  /// Adds [node] as a child of the current parent.
  ///
  /// If [through] is passed, [node] is added as a child of the first parent for
  /// which [through] returns `false` instead. That parent is copied unless it's the
  /// lattermost child of its parent.
  void _addChild(ModifiableCssNode node, {bool through(CssNode node)}) {
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
  }

  /// Runs [callback] with [rule] as the current style rule.
  T _withStyleRule<T>(ModifiableCssStyleRule rule, T callback()) {
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

  /// Adds a frame to the stack with the given [member] name, and [nodeWithSpan]
  /// as the site of the new frame.
  ///
  /// Runs [callback] with the new stack.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  T _withStackFrame<T>(String member, AstNode nodeWithSpan, T callback()) {
    _stack.add(Tuple2(_member, nodeWithSpan));
    var oldMember = _member;
    _member = member;
    var result = callback();
    _member = oldMember;
    _stack.removeLast();
    return result;
  }

  /// Creates a new stack frame with location information from [member] and
  /// [span].
  Frame _stackFrame(String member, FileSpan span) {
    var url = span.sourceUrl;
    if (url != null && _importCache != null) url = _importCache.humanize(url);
    return frameForSpan(span, member, url: url);
  }

  /// Returns a stack trace at the current point.
  ///
  /// If [span] is passed, it's used for the innermost stack frame.
  Trace _stackTrace([FileSpan span]) {
    var frames = [
      ..._stack.map((tuple) => _stackFrame(tuple.item1, tuple.item2.span)),
      if (span != null) _stackFrame(_member, span)
    ];
    return Trace(frames.reversed);
  }

  /// Emits a warning with the given [message] about the given [span].
  void _warn(String message, FileSpan span, {bool deprecation = false}) =>
      _logger.warn(message,
          span: span, trace: _stackTrace(span), deprecation: deprecation);

  /// Throws a [SassRuntimeException] with the given [message].
  ///
  /// If [span] is passed, it's used for the innermost stack frame.
  SassRuntimeException _exception(String message, [FileSpan span]) =>
      SassRuntimeException(
          message, span ?? _stack.last.item2.span, _stackTrace(span));

  /// Runs [callback], and adjusts any [SassFormatException] to be within
  /// [nodeWithSpan]'s source span.
  ///
  /// Specifically, this adjusts format exceptions so that the errors are
  /// reported as though the text being parsed were exactly in [span]. This may
  /// not be quite accurate if the source text contained interpolation, but
  /// it'll still produce a useful error.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  T _adjustParseError<T>(AstNode nodeWithSpan, T callback()) {
    try {
      return callback();
    } on SassFormatException catch (error) {
      var errorText = error.span.file.getText(0);
      var span = nodeWithSpan.span;
      var syntheticFile = span.file
          .getText(0)
          .replaceRange(span.start.offset, span.end.offset, errorText);
      var syntheticSpan =
          SourceFile.fromString(syntheticFile, url: span.file.url).span(
              span.start.offset + error.span.start.offset,
              span.start.offset + error.span.end.offset);
      throw _exception(error.message, syntheticSpan);
    }
  }

  /// Runs [callback], and converts any [SassScriptException]s it throws to
  /// [SassRuntimeException]s with [nodeWithSpan]'s source span.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  T _addExceptionSpan<T>(AstNode nodeWithSpan, T callback()) {
    try {
      return callback();
    } on SassScriptException catch (error) {
      throw _exception(error.message, nodeWithSpan.span);
    }
  }

  /// Runs [callback], and converts any [SassRuntimeException]s containing an
  /// @error to throw a more relevant [SassRuntimeException] with [nodeWithSpan]'s
  /// source span.
  T _addErrorSpan<T>(AstNode nodeWithSpan, T callback()) {
    try {
      return callback();
    } on SassRuntimeException catch (error) {
      if (!error.span.text.startsWith("@error")) rethrow;
      throw SassRuntimeException(
          error.message, nodeWithSpan.span, _stackTrace());
    }
  }
}

/// A helper class for [_EvaluateVisitor] that adds `@import`ed CSS nodes to the
/// root stylesheet.
///
/// We can't evaluate the imported stylesheet with the original stylesheet as
/// its root because it may `@use` modules that need to be injected before the
/// imported stylesheet's CSS.
///
/// We also can't use [_EvaluateVisitor]'s implementation of [CssVisitor]
/// because it will add the parent selector to the CSS if the `@import` appeared
/// in a nested context, but the parent selector was already added when the
/// imported stylesheet was evaluated.
class _ImportedCssVisitor implements ModifiableCssVisitor<void> {
  /// The visitor in whose context this was created.
  final _EvaluateVisitor _visitor;

  _ImportedCssVisitor(this._visitor);

  void visitCssAtRule(ModifiableCssAtRule node) {
    _visitor._addChild(node,
        through: node.isChildless ? null : (node) => node is CssStyleRule);
  }

  void visitCssComment(ModifiableCssComment node) => _visitor._addChild(node);

  void visitCssDeclaration(ModifiableCssDeclaration node) {
    assert(false, "visitCssDeclaration() should never be called.");
  }

  void visitCssImport(ModifiableCssImport node) {
    if (_visitor._parent != _visitor._root) {
      _visitor._addChild(node);
    } else if (_visitor._endOfImports == _visitor._root.children.length) {
      _visitor._addChild(node);
      _visitor._endOfImports++;
    } else {
      _visitor._outOfOrderImports ??= [];
      _visitor._outOfOrderImports.add(node);
    }
  }

  void visitCssKeyframeBlock(ModifiableCssKeyframeBlock node) {
    assert(false, "visitCssKeyframeBlock() should never be called.");
  }

  void visitCssMediaRule(ModifiableCssMediaRule node) {
    // Whether [node.query] has been merged with [_visitor._mediaQueries]. If it
    // has been merged, merging again is a no-op; if it hasn't been merged,
    // merging again will fail.
    var hasBeenMerged = _visitor._mediaQueries == null ||
        _visitor._mergeMediaQueries(_visitor._mediaQueries, node.queries) !=
            null;

    _visitor._addChild(node,
        through: (node) =>
            node is CssStyleRule || (hasBeenMerged && node is CssMediaRule));
  }

  void visitCssStyleRule(ModifiableCssStyleRule node) =>
      _visitor._addChild(node, through: (node) => node is CssStyleRule);

  void visitCssStylesheet(ModifiableCssStylesheet node) {
    for (var child in node.children) {
      child.accept(this);
    }
  }

  void visitCssSupportsRule(ModifiableCssSupportsRule node) =>
      _visitor._addChild(node, through: (node) => node is CssStyleRule);
}

/// The result of evaluating arguments to a function or mixin.
class _ArgumentResults {
  /// Arguments passed by position.
  final List<Value> positional;

  /// The [AstNode]s that hold the spans for each [positional] argument, or
  /// `null` if source span tracking is disabled.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final List<AstNode> positionalNodes;

  /// Arguments passed by name.
  final Map<String, Value> named;

  /// The [AstNode]s that hold the spans for each [named] argument, or `null` if
  /// source span tracking is disabled.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final Map<String, AstNode> namedNodes;

  /// The separator used for the rest argument list, if any.
  final ListSeparator separator;

  _ArgumentResults(this.positional, this.named, this.separator,
      {this.positionalNodes, this.namedNodes});
}
