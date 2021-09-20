// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/css/modifiable.dart';
import '../ast/node.dart';
import '../ast/sass.dart';
import '../ast/selector.dart';
import '../async_environment.dart';
import '../async_import_cache.dart';
import '../callable.dart';
import '../color_names.dart';
import '../configuration.dart';
import '../configured_value.dart';
import '../exception.dart';
import '../extend/extension_store.dart';
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
import '../utils.dart';
import '../util/nullable.dart';
import '../value.dart';
import '../warn.dart';
import 'interface/css.dart';
import 'interface/expression.dart';
import 'interface/modifiable_css.dart';
import 'interface/statement.dart';

/// A function that takes a callback with no arguments.
typedef _ScopeCallback = Future<void> Function(
    Future<void> Function() callback);

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
Future<EvaluateResult> evaluateAsync(Stylesheet stylesheet,
        {AsyncImportCache? importCache,
        NodeImporter? nodeImporter,
        AsyncImporter? importer,
        Iterable<AsyncCallable>? functions,
        Logger? logger,
        bool quietDeps = false,
        bool sourceMap = false}) =>
    _EvaluateVisitor(
            importCache: importCache,
            nodeImporter: nodeImporter,
            functions: functions,
            logger: logger,
            quietDeps: quietDeps,
            sourceMap: sourceMap)
        .run(importer, stylesheet);

/// A class that can evaluate multiple independent statements and expressions
/// in the context of a single module.
class AsyncEvaluator {
  /// The visitor that evaluates each expression and statement.
  final _EvaluateVisitor _visitor;

  /// The importer to use to resolve `@use` rules in [_visitor].
  final AsyncImporter? _importer;

  /// Creates an evaluator.
  ///
  /// Arguments are the same as for [evaluateAsync].
  AsyncEvaluator(
      {AsyncImportCache? importCache,
      AsyncImporter? importer,
      Iterable<AsyncCallable>? functions,
      Logger? logger})
      : _visitor = _EvaluateVisitor(
            importCache: importCache, functions: functions, logger: logger),
        _importer = importer;

  Future<void> use(UseRule use) => _visitor.runStatement(_importer, use);

  Future<Value> evaluate(Expression expression) =>
      _visitor.runExpression(_importer, expression);

  Future<void> setVariable(VariableDeclaration declaration) =>
      _visitor.runStatement(_importer, declaration);
}

/// A visitor that executes Sass code to produce a CSS tree.
class _EvaluateVisitor
    implements
        StatementVisitor<Future<Value?>>,
        ExpressionVisitor<Future<Value>>,
        CssVisitor<Future<void>> {
  /// The import cache used to import other stylesheets.
  final AsyncImportCache? _importCache;

  /// The Node Sass-compatible importer to use when loading new Sass files when
  /// compiled to Node.js.
  final NodeImporter? _nodeImporter;

  /// Built-in functions that are globally-accessible, even under the new module
  /// system.
  final _builtInFunctions = <String, AsyncCallable>{};

  /// Built in modules, indexed by their URLs.
  final _builtInModules = <Uri, Module>{};

  /// All modules that have been loaded and evaluated so far.
  final _modules = <Uri, Module>{};

  /// A map from canonical module URLs to the nodes whose spans indicate where
  /// those modules were originally loaded.
  ///
  /// This is not guaranteed to have a node for every module in [_modules]. For
  /// example, the entrypoint module was not loaded by a node.
  final _moduleNodes = <Uri, AstNode>{};

  /// The logger to use to print warnings.
  final Logger _logger;

  /// A set of message/location pairs for warnings that have been emitted via
  /// [_warn].
  ///
  /// We only want to emit one warning per location, to avoid blowing up users'
  /// consoles with redundant warnings.
  final _warningsEmitted = <Tuple2<String, SourceSpan>>{};

  /// Whether to avoid emitting warnings for files loaded from dependencies.
  final bool _quietDeps;

  /// Whether to track source map information.
  final bool _sourceMap;

  /// The current lexical environment.
  AsyncEnvironment _environment;

  /// The style rule that defines the current parent selector, if any.
  ///
  /// This doesn't take into consideration any intermediate `@at-root` rules. In
  /// the common case where those rules are relevant, use [_styleRule] instead.
  ModifiableCssStyleRule? _styleRuleIgnoringAtRoot;

  /// The current media queries, if any.
  List<CssMediaQuery>? _mediaQueries;

  /// The current parent node in the output CSS tree.
  ModifiableCssParentNode get _parent => _assertInModule(__parent, "__parent");
  set _parent(ModifiableCssParentNode value) => __parent = value;

  ModifiableCssParentNode? __parent;

  /// The name of the current declaration parent.
  String? _declarationName;

  /// The human-readable name of the current stack frame.
  var _member = "root stylesheet";

  /// The node for the innermost callable that's being invoked.
  ///
  /// This is used to produce warnings for function calls. It's stored as an
  /// [AstNode] rather than a [FileSpan] so we can avoid calling [AstNode.span]
  /// if the span isn't required, since some nodes need to do real work to
  /// manufacture a source span.
  AstNode? _callableNode;

  /// The span for the current import that's being resolved.
  ///
  /// This is used to produce warnings for importers.
  FileSpan? _importSpan;

  /// Whether we're currently executing a function.
  var _inFunction = false;

  /// Whether we're currently building the output of an unknown at rule.
  var _inUnknownAtRule = false;

  ModifiableCssStyleRule? get _styleRule =>
      _atRootExcludingStyleRule ? null : _styleRuleIgnoringAtRoot;

  /// Whether we're directly within an `@at-root` rule that excludes style
  /// rules.
  var _atRootExcludingStyleRule = false;

  /// Whether we're currently building the output of a `@keyframes` rule.
  var _inKeyframes = false;

  /// The canonical URLs of all stylesheets loaded during compilation.
  final _loadedUrls = <Uri>{};

  /// A map from canonical URLs for modules (or imported files) that are
  /// currently being evaluated to AST nodes whose spans indicate the original
  /// loads for those modules.
  ///
  /// Map values may be `null`, which indicates an active module that doesn't
  /// have a source span associated with its original load (such as the
  /// entrypoint module).
  ///
  /// This is used to ensure that we don't get into an infinite load loop.
  final _activeModules = <Uri, AstNode?>{};

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
  AsyncImporter? _importer;

  /// Whether we're in a dependency.
  ///
  /// A dependency is defined as a stylesheet imported by an importer other than
  /// the original. In Node importers, nothing is considered a dependency.
  var _inDependency = false;

  /// The stylesheet that's currently being evaluated.
  Stylesheet get _stylesheet => _assertInModule(__stylesheet, "_stylesheet");
  set _stylesheet(Stylesheet value) => __stylesheet = value;
  Stylesheet? __stylesheet;

  /// The root stylesheet node.
  ModifiableCssStylesheet get _root => _assertInModule(__root, "_root");
  set _root(ModifiableCssStylesheet value) => __root = value;
  ModifiableCssStylesheet? __root;

  /// The first index in [_root.children] after the initial block of CSS
  /// imports.
  int get _endOfImports => _assertInModule(__endOfImports, "_endOfImports");
  set _endOfImports(int value) => __endOfImports = value;
  int? __endOfImports;

  /// Plain-CSS imports that didn't appear in the initial block of CSS imports.
  ///
  /// These are added to the initial CSS import block by [visitStylesheet] after
  /// the stylesheet has been fully performed.
  ///
  /// This is `null` unless there are any out-of-order imports in the current
  /// stylesheet.
  List<ModifiableCssImport>? _outOfOrderImports;

  /// The extension store that tracks extensions and style rules for the current
  /// module.
  ExtensionStore get _extensionStore =>
      _assertInModule(__extensionStore, "_extensionStore");
  set _extensionStore(ExtensionStore value) => __extensionStore = value;
  ExtensionStore? __extensionStore;

  /// The configuration for the current module.
  ///
  /// If this is empty, that indicates that the current module is not configured.
  var _configuration = const Configuration.empty();

  /// Creates a new visitor.
  ///
  /// Most arguments are the same as those to [evaluateAsync].
  _EvaluateVisitor(
      {AsyncImportCache? importCache,
      NodeImporter? nodeImporter,
      Iterable<AsyncCallable>? functions,
      Logger? logger,
      bool quietDeps = false,
      bool sourceMap = false})
      : _importCache = nodeImporter == null
            ? importCache ?? AsyncImportCache.none(logger: logger)
            : null,
        _nodeImporter = nodeImporter,
        _logger = logger ?? const Logger.stderr(),
        _quietDeps = quietDeps,
        _sourceMap = sourceMap,
        // The default environment is overridden in [_execute] for full
        // stylesheets, but for [AsyncEvaluator] this environment is used.
        _environment = AsyncEnvironment() {
    var metaFunctions = [
      // These functions are defined in the context of the evaluator because
      // they need access to the [_environment] or other local state.
      BuiltInCallable.function(
          "global-variable-exists", r"$name, $module: null", (arguments) {
        var variable = arguments[0].assertString("name");
        var module = arguments[1].realNull?.assertString("module");
        return SassBoolean(_environment.globalVariableExists(
            variable.text.replaceAll("_", "-"),
            namespace: module?.text));
      }, url: "sass:meta"),

      BuiltInCallable.function("variable-exists", r"$name", (arguments) {
        var variable = arguments[0].assertString("name");
        return SassBoolean(
            _environment.variableExists(variable.text.replaceAll("_", "-")));
      }, url: "sass:meta"),

      BuiltInCallable.function("function-exists", r"$name, $module: null",
          (arguments) {
        var variable = arguments[0].assertString("name");
        var module = arguments[1].realNull?.assertString("module");
        return SassBoolean(_environment.functionExists(
                variable.text.replaceAll("_", "-"),
                namespace: module?.text) ||
            _builtInFunctions.containsKey(variable.text));
      }, url: "sass:meta"),

      BuiltInCallable.function("mixin-exists", r"$name, $module: null",
          (arguments) {
        var variable = arguments[0].assertString("name");
        var module = arguments[1].realNull?.assertString("module");
        return SassBoolean(_environment.mixinExists(
            variable.text.replaceAll("_", "-"),
            namespace: module?.text));
      }, url: "sass:meta"),

      BuiltInCallable.function("content-exists", "", (arguments) {
        if (!_environment.inMixin) {
          throw SassScriptException(
              "content-exists() may only be called within a mixin.");
        }
        return SassBoolean(_environment.content != null);
      }, url: "sass:meta"),

      BuiltInCallable.function("module-variables", r"$module", (arguments) {
        var namespace = arguments[0].assertString("module");
        var module = _environment.modules[namespace.text];
        if (module == null) {
          throw 'There is no module with namespace "${namespace.text}".';
        }

        return SassMap({
          for (var entry in module.variables.entries)
            SassString(entry.key): entry.value
        });
      }, url: "sass:meta"),

      BuiltInCallable.function("module-functions", r"$module", (arguments) {
        var namespace = arguments[0].assertString("module");
        var module = _environment.modules[namespace.text];
        if (module == null) {
          throw 'There is no module with namespace "${namespace.text}".';
        }

        return SassMap({
          for (var entry in module.functions.entries)
            SassString(entry.key): SassFunction(entry.value)
        });
      }, url: "sass:meta"),

      BuiltInCallable.function(
          "get-function", r"$name, $css: false, $module: null", (arguments) {
        var name = arguments[0].assertString("name");
        var css = arguments[1].isTruthy;
        var module = arguments[2].realNull?.assertString("module");

        if (css && module != null) {
          throw r"$css and $module may not both be passed at once.";
        }

        var callable = css
            ? PlainCssCallable(name.text)
            : _addExceptionSpan(
                _callableNode!,
                () => _getFunction(name.text.replaceAll("_", "-"),
                    namespace: module?.text));
        if (callable != null) return SassFunction(callable);

        throw "Function not found: $name";
      }, url: "sass:meta"),

      AsyncBuiltInCallable.function("call", r"$function, $args...",
          (arguments) async {
        var function = arguments[0];
        var args = arguments[1] as SassArgumentList;

        var callableNode = _callableNode!;
        var invocation = ArgumentInvocation([], {}, callableNode.span,
            rest: ValueExpression(args, callableNode.span),
            keywordRest: args.keywords.isEmpty
                ? null
                : ValueExpression(
                    SassMap({
                      for (var entry in args.keywords.entries)
                        SassString(entry.key, quotes: false): entry.value
                    }),
                    callableNode.span));

        if (function is SassString) {
          warn(
              "Passing a string to call() is deprecated and will be illegal in "
              "Dart Sass 2.0.0.\n"
              "\n"
              "Recommendation: call(get-function($function))",
              deprecation: true);

          var callableNode = _callableNode!;
          var expression =
              FunctionExpression(function.text, invocation, callableNode.span);
          return await expression.accept(this);
        }

        var callable = function.assertFunction("function").callable;
        // ignore: unnecessary_type_check
        if (callable is AsyncCallable) {
          return await _runFunctionCallable(
              invocation, callable, _callableNode!);
        } else {
          throw SassScriptException(
              "The function ${callable.name} is asynchronous.\n"
              "This is probably caused by a bug in a Sass plugin.");
        }
      }, url: "sass:meta")
    ];

    var metaMixins = [
      AsyncBuiltInCallable.mixin("load-css", r"$url, $with: null",
          (arguments) async {
        var url = Uri.parse(arguments[0].assertString("url").text);
        var withMap = arguments[1].realNull?.assertMap("with").contents;

        var callableNode = _callableNode!;
        var configuration = const Configuration.empty();
        if (withMap != null) {
          var values = <String, ConfiguredValue>{};
          var span = callableNode.span;
          withMap.forEach((variable, value) {
            var name =
                variable.assertString("with key").text.replaceAll("_", "-");
            if (values.containsKey(name)) {
              throw "The variable \$$name was configured twice.";
            }

            values[name] = ConfiguredValue.explicit(value, span, callableNode);
          });
          configuration = ExplicitConfiguration(values, callableNode);
        }

        await _loadModule(url, "load-css()", callableNode,
            (module) => _combineCss(module, clone: true).accept(this),
            baseUrl: callableNode.span.sourceUrl,
            configuration: configuration,
            namesInErrors: true);
        _assertConfigurationIsEmpty(configuration, nameInError: true);

        return null;
      }, url: "sass:meta")
    ];

    var metaModule = BuiltInModule("meta",
        functions: [...meta.global, ...meta.local, ...metaFunctions],
        mixins: metaMixins);

    for (var module in [...coreModules, metaModule]) {
      _builtInModules[module.url] = module;
    }

    functions = [...?functions, ...globalFunctions, ...metaFunctions];
    for (var function in functions) {
      _builtInFunctions[function.name.replaceAll("_", "-")] = function;
    }
  }

  Future<EvaluateResult> run(AsyncImporter? importer, Stylesheet node) async {
    return _withWarnCallback(node, () async {
      var url = node.span.sourceUrl;
      if (url != null) {
        _activeModules[url] = null;
        if (!(_asNodeSass && url.toString() == 'stdin')) _loadedUrls.add(url);
      }

      var module = await _execute(importer, node);

      return EvaluateResult(_combineCss(module), _loadedUrls);
    });
  }

  Future<Value> runExpression(AsyncImporter? importer, Expression expression) =>
      _withWarnCallback(
          expression,
          () => _withFakeStylesheet(
              importer, expression, () => expression.accept(this)));

  Future<void> runStatement(AsyncImporter? importer, Statement statement) =>
      _withWarnCallback(
          statement,
          () => _withFakeStylesheet(
              importer, statement, () => statement.accept(this)));

  /// Runs [callback] with a definition for the top-level `warn` function.
  ///
  /// If no other span can be found to report a warning, falls back on
  /// [nodeWithSpan]'s.
  T _withWarnCallback<T>(AstNode nodeWithSpan, T callback()) {
    return withWarnCallback(
        (message, deprecation) => _warn(
            message, _importSpan ?? _callableNode?.span ?? nodeWithSpan.span,
            deprecation: deprecation),
        callback);
  }

  /// Asserts that [value] is not `null` and returns it.
  ///
  /// This is used for fields that are set whenever the evaluator is evaluating
  /// a module, which is to say essentially all the time (unless running via
  /// [runExpression] or [runStatement]).
  T _assertInModule<T>(T? value, String name) {
    if (value != null) return value;
    throw StateError("Can't access $name outside of a module.");
  }

  /// Runs [callback] with [importer] as [_importer] and a fake [_stylesheet]
  /// with [nodeWithSpan]'s source span.
  Future<T> _withFakeStylesheet<T>(AsyncImporter? importer,
      AstNode nodeWithSpan, FutureOr<T> callback()) async {
    var oldImporter = _importer;
    _importer = importer;

    assert(__stylesheet == null);
    _stylesheet = Stylesheet(const [], nodeWithSpan.span);

    try {
      return await callback();
    } finally {
      _importer = oldImporter;
      __stylesheet = null;
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
  /// The [stackFrame] and [nodeWithSpan] are used for the name and location of
  /// the stack frame for the duration of the [callback].
  Future<void> _loadModule(Uri url, String stackFrame, AstNode nodeWithSpan,
      FutureOr<void> callback(Module module),
      {Uri? baseUrl,
      Configuration? configuration,
      bool namesInErrors = false}) async {
    var builtInModule = _builtInModules[url];
    if (builtInModule != null) {
      if (configuration is ExplicitConfiguration) {
        throw _exception(
            namesInErrors
                ? "Built-in module $url can't be configured."
                : "Built-in modules can't be configured.",
            configuration.nodeWithSpan.span);
      }

      await _addExceptionSpanAsync(nodeWithSpan, () => callback(builtInModule));
      return;
    }

    await _withStackFrame(stackFrame, nodeWithSpan, () async {
      var result = await _loadStylesheet(url.toString(), nodeWithSpan.span,
          baseUrl: baseUrl);
      var stylesheet = result.stylesheet;

      var canonicalUrl = stylesheet.span.sourceUrl;
      if (canonicalUrl != null && _activeModules.containsKey(canonicalUrl)) {
        var message = namesInErrors
            ? "Module loop: ${p.prettyUri(canonicalUrl)} is already being "
                "loaded."
            : "Module loop: this module is already being loaded.";

        throw _activeModules[canonicalUrl].andThen((previousLoad) =>
                _multiSpanException(message, "new load",
                    {previousLoad.span: "original load"})) ??
            _exception(message);
      }
      if (canonicalUrl != null) _activeModules[canonicalUrl] = nodeWithSpan;

      var oldInDependency = _inDependency;
      _inDependency = result.isDependency;
      Module module;
      try {
        module = await _execute(result.importer, stylesheet,
            configuration: configuration,
            nodeWithSpan: nodeWithSpan,
            namesInErrors: namesInErrors);
      } finally {
        _activeModules.remove(canonicalUrl);
        _inDependency = oldInDependency;
      }

      try {
        await callback(module);
      } on SassRuntimeException {
        rethrow;
      } on MultiSpanSassException catch (error) {
        throw MultiSpanSassRuntimeException(error.message, error.span,
            error.primaryLabel, error.secondarySpans, _stackTrace(error.span));
      } on SassException catch (error) {
        throw _exception(error.message, error.span);
      } on MultiSpanSassScriptException catch (error) {
        throw _multiSpanException(
            error.message, error.primaryLabel, error.secondarySpans);
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
  Future<Module> _execute(AsyncImporter? importer, Stylesheet stylesheet,
      {Configuration? configuration,
      AstNode? nodeWithSpan,
      bool namesInErrors = false}) async {
    var url = stylesheet.span.sourceUrl;

    var alreadyLoaded = _modules[url];
    if (alreadyLoaded != null) {
      var currentConfiguration = configuration ?? _configuration;
      if (currentConfiguration is ExplicitConfiguration) {
        var message = namesInErrors
            ? "${p.prettyUri(url)} was already loaded, so it can't be "
                "configured using \"with\"."
            : "This module was already loaded, so it can't be configured using "
                "\"with\".";

        var existingSpan = _moduleNodes[url]?.span;
        var configurationSpan = configuration == null
            ? currentConfiguration.nodeWithSpan.span
            : null;
        var secondarySpans = {
          if (existingSpan != null) existingSpan: "original load",
          if (configurationSpan != null) configurationSpan: "configuration"
        };

        throw secondarySpans.isEmpty
            ? _exception(message)
            : _multiSpanException(message, "new load", secondarySpans);
      }

      return alreadyLoaded;
    }

    var environment = AsyncEnvironment();
    late CssStylesheet css;
    var extensionStore = ExtensionStore();
    await _withEnvironment(environment, () async {
      var oldImporter = _importer;
      var oldStylesheet = __stylesheet;
      var oldRoot = __root;
      var oldParent = __parent;
      var oldEndOfImports = __endOfImports;
      var oldOutOfOrderImports = _outOfOrderImports;
      var oldExtensionStore = __extensionStore;
      var oldStyleRule = _styleRule;
      var oldMediaQueries = _mediaQueries;
      var oldDeclarationName = _declarationName;
      var oldInUnknownAtRule = _inUnknownAtRule;
      var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
      var oldInKeyframes = _inKeyframes;
      var oldConfiguration = _configuration;
      _importer = importer;
      _stylesheet = stylesheet;
      var root = __root = ModifiableCssStylesheet(stylesheet.span);
      _parent = root;
      _endOfImports = 0;
      _outOfOrderImports = null;
      _extensionStore = extensionStore;
      _styleRuleIgnoringAtRoot = null;
      _mediaQueries = null;
      _declarationName = null;
      _inUnknownAtRule = false;
      _atRootExcludingStyleRule = false;
      _inKeyframes = false;
      if (configuration != null) _configuration = configuration;

      await visitStylesheet(stylesheet);
      css = _outOfOrderImports == null
          ? root
          : CssStylesheet(_addOutOfOrderImports(), stylesheet.span);

      _importer = oldImporter;
      __stylesheet = oldStylesheet;
      __root = oldRoot;
      __parent = oldParent;
      __endOfImports = oldEndOfImports;
      _outOfOrderImports = oldOutOfOrderImports;
      __extensionStore = oldExtensionStore;
      _styleRuleIgnoringAtRoot = oldStyleRule;
      _mediaQueries = oldMediaQueries;
      _declarationName = oldDeclarationName;
      _inUnknownAtRule = oldInUnknownAtRule;
      _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;
      _inKeyframes = oldInKeyframes;
      _configuration = oldConfiguration;
    });

    var module = environment.toModule(css, extensionStore);
    if (url != null) {
      _modules[url] = module;
      if (nodeWithSpan != null) _moduleNodes[url] = nodeWithSpan;
    }

    return module;
  }

  /// Returns a copy of [_root.children] with [_outOfOrderImports] inserted
  /// after [_endOfImports], if necessary.
  List<ModifiableCssNode> _addOutOfOrderImports() {
    var outOfOrderImports = _outOfOrderImports;
    if (outOfOrderImports == null) return _root.children;

    return [
      ..._root.children.take(_endOfImports),
      ...outOfOrderImports,
      ..._root.children.skip(_endOfImports)
    ];
  }

  /// Returns a new stylesheet containing [root]'s CSS as well as the CSS of all
  /// modules transitively used by [root].
  ///
  /// This also applies each module's extensions to its upstream modules.
  ///
  /// If [clone] is `true`, this will copy the modules before extending them so
  /// that they don't modify [root] or its dependencies.
  CssStylesheet _combineCss(Module root, {bool clone = false}) {
    if (!root.upstream.any((module) => module.transitivelyContainsCss)) {
      var selectors = root.extensionStore.simpleSelectors;
      var unsatisfiedExtension = firstOrNull(root.extensionStore
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
  void _extendModules(List<Module> sortedModules) {
    // All the [ExtensionStore]s directly downstream of a given module (indexed
    // by its canonical URL). It's important that we create this in topological
    // order, so that by the time we're processing a module we've already filled
    // in all its downstream [ExtensionStore]s and we can use them to extend
    // that module.
    var downstreamExtensionStores = <Uri, List<ExtensionStore>>{};

    /// Extensions that haven't yet been satisfied by some upstream module. This
    /// adds extensions when they're defined but not satisfied, and removes them
    /// when they're satisfied by any module.
    var unsatisfiedExtensions = Set<Extension>.identity();

    for (var module in sortedModules) {
      // Create a snapshot of the simple selectors currently in the
      // [ExtensionStore] so that we don't consider an extension "satisfied"
      // below because of a simple selector added by another (sibling)
      // extension.
      var originalSelectors = module.extensionStore.simpleSelectors.toSet();

      // Add all as-yet-unsatisfied extensions before adding downstream
      // [ExtensionStore]s, because those are all in [unsatisfiedExtensions]
      // already.
      unsatisfiedExtensions.addAll(module.extensionStore.extensionsWhereTarget(
          (target) => !originalSelectors.contains(target)));

      downstreamExtensionStores[module.url]
          .andThen(module.extensionStore.addExtensions);
      if (module.extensionStore.isEmpty) continue;

      for (var upstream in module.upstream) {
        var url = upstream.url;
        if (url == null) continue;
        downstreamExtensionStores
            .putIfAbsent(url, () => [])
            .add(module.extensionStore);
      }

      // Remove all extensions that are now satisfied after adding downstream
      // [ExtensionStore]s so it counts any downstream extensions that have been
      // newly satisfied.
      unsatisfiedExtensions.removeAll(module.extensionStore
          .extensionsWhereTarget(originalSelectors.contains));
    }

    if (unsatisfiedExtensions.isNotEmpty) {
      _throwForUnsatisfiedExtension(unsatisfiedExtensions.first);
    }
  }

  /// Throws an exception indicating that [extension] is unsatisfied.
  Never _throwForUnsatisfiedExtension(Extension extension) {
    throw SassException(
        'The target selector was not found.\n'
        'Use "@extend ${extension.target} !optional" to avoid this error.',
        extension.span);
  }

  /// Returns all modules transitively used by [root] in topological order,
  /// ignoring modules that contain no CSS.
  List<Module> _topologicalModules(Module root) {
    // Construct a topological ordering using depth-first traversal, as in
    // https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search.
    var seen = <Module>{};
    var sorted = QueueList<Module>();

    void visitModule(Module module) {
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

  Future<Value?> visitStylesheet(Stylesheet node) async {
    for (var child in node.children) {
      await child.accept(this);
    }
    return null;
  }

  Future<Value?> visitAtRootRule(AtRootRule node) async {
    var query = AtRootQuery.defaultQuery;
    var unparsedQuery = node.query;
    if (unparsedQuery != null) {
      var resolved =
          await _performInterpolation(unparsedQuery, warnForColor: true);
      query = _adjustParseError(
          unparsedQuery, () => AtRootQuery.parse(resolved, logger: _logger));
    }

    var parent = _parent;
    var included = <ModifiableCssParentNode>[];
    while (parent is! CssStylesheet) {
      if (!query.excludes(parent)) included.add(parent);

      var grandparent = parent.parent;
      if (grandparent == null) {
        throw StateError(
            "CssNodes must have a CssStylesheet transitive parent node.");
      }

      parent = grandparent;
    }
    var root = _trimIncluded(included);

    // If we didn't exclude any rules, we don't need to use the copies we might
    // have created.
    if (root == _parent) {
      await _environment.scope(() async {
        for (var child in node.children) {
          await child.accept(this);
        }
      }, when: node.hasDeclarations);
      return null;
    }

    var innerCopy = root;
    if (included.isNotEmpty) {
      innerCopy = included.first.copyWithoutChildren();
      var outerCopy = innerCopy;
      for (var node in included.skip(1)) {
        var copy = node.copyWithoutChildren();
        copy.addChild(outerCopy);
        outerCopy = copy;
      }

      root.addChild(outerCopy);
    }

    await _scopeForAtRoot(node, innerCopy, query, included)(() async {
      for (var child in node.children) {
        await child.accept(this);
      }
    });

    return null;
  }

  /// Destructively trims a trailing sublist from [nodes] that matches the
  /// current list of parents.
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
    int? innermostContiguous;
    for (var i = 0; i < nodes.length; i++) {
      while (parent != nodes[i]) {
        innermostContiguous = null;

        var grandparent = parent.parent;
        if (grandparent == null) {
          throw ArgumentError(
              "Expected ${nodes[i]} to be an ancestor of $this.");
        }

        parent = grandparent;
      }
      innermostContiguous ??= i;

      var grandparent = parent.parent;
      if (grandparent == null) {
        throw ArgumentError("Expected ${nodes[i]} to be an ancestor of $this.");
      }
      parent = grandparent;
    }

    if (parent != _root) return _root;
    var root = nodes[innermostContiguous!];
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
    var scope = (Future<void> callback()) async {
      // We can't use [_withParent] here because it'll add the node to the tree
      // in the wrong place.
      var oldParent = _parent;
      _parent = newParent;
      await _environment.scope(callback, when: node.hasDeclarations);
      _parent = oldParent;
    };

    if (query.excludesStyleRules) {
      var innerScope = scope;
      scope = (callback) async {
        var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
        _atRootExcludingStyleRule = true;
        await innerScope(callback);
        _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;
      };
    }

    if (_mediaQueries != null && query.excludesName('media')) {
      var innerScope = scope;
      scope = (callback) => _withMediaQueries(null, () => innerScope(callback));
    }

    if (_inKeyframes && query.excludesName('keyframes')) {
      var innerScope = scope;
      scope = (callback) async {
        var wasInKeyframes = _inKeyframes;
        _inKeyframes = false;
        await innerScope(callback);
        _inKeyframes = wasInKeyframes;
      };
    }

    if (_inUnknownAtRule && !included.any((parent) => parent is CssAtRule)) {
      var innerScope = scope;
      scope = (callback) async {
        var wasInUnknownAtRule = _inUnknownAtRule;
        _inUnknownAtRule = false;
        await innerScope(callback);
        _inUnknownAtRule = wasInUnknownAtRule;
      };
    }

    return scope;
  }

  Future<Value> visitContentBlock(ContentBlock node) => throw UnsupportedError(
      "Evaluation handles @include and its content block together.");

  Future<Value?> visitContentRule(ContentRule node) async {
    var content = _environment.content;
    if (content == null) return null;

    await _runUserDefinedCallable(node.arguments, content, node, () async {
      for (var statement in content.declaration.children) {
        await statement.accept(this);
      }
      return null;
    });

    return null;
  }

  Future<Value?> visitDebugRule(DebugRule node) async {
    var value = await node.expression.accept(this);
    _logger.debug(
        value is SassString ? value.text : value.toString(), node.span);
    return null;
  }

  Future<Value?> visitDeclaration(Declaration node) async {
    if (_styleRule == null && !_inUnknownAtRule && !_inKeyframes) {
      throw _exception(
          "Declarations may only be used within style rules.", node.span);
    }

    var name = await _interpolationToValue(node.name, warnForColor: true);
    if (_declarationName != null) {
      name = CssValue("$_declarationName-${name.value}", name.span);
    }
    var cssValue = await node.value.andThen(
        (value) async => CssValue(await value.accept(this), value.span));

    // If the value is an empty list, preserve it, because converting it to CSS
    // will throw an error that we want the user to see.
    if (cssValue != null &&
        (!cssValue.value.isBlank || _isEmptyList(cssValue.value))) {
      _parent.addChild(ModifiableCssDeclaration(name, cssValue, node.span,
          parsedAsCustomProperty: node.isCustomProperty,
          valueSpanForMap:
              _sourceMap ? node.value.andThen(_expressionNode)?.span : null));
    } else if (name.value.startsWith('--') && cssValue != null) {
      throw _exception(
          "Custom property values may not be empty.", cssValue.span);
    }

    var children = node.children;
    if (children != null) {
      var oldDeclarationName = _declarationName;
      _declarationName = name.value;
      await _environment.scope(() async {
        for (var child in children) {
          await child.accept(this);
        }
      }, when: node.hasDeclarations);
      _declarationName = oldDeclarationName;
    }

    return null;
  }

  /// Returns whether [value] is an empty list.
  bool _isEmptyList(Value value) => value.asList.isEmpty;

  Future<Value?> visitEachRule(EachRule node) async {
    var list = await node.list.accept(this);
    var nodeWithSpan = _expressionNode(node.list);
    var setVariables = node.variables.length == 1
        ? (Value value) => _environment.setLocalVariable(node.variables.first,
            _withoutSlash(value, nodeWithSpan), nodeWithSpan)
        : (Value value) =>
            _setMultipleVariables(node.variables, value, nodeWithSpan);
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
      List<String> variables, Value value, AstNode nodeWithSpan) {
    var list = value.asList;
    var minLength = math.min(variables.length, list.length);
    for (var i = 0; i < minLength; i++) {
      _environment.setLocalVariable(
          variables[i], _withoutSlash(list[i], nodeWithSpan), nodeWithSpan);
    }
    for (var i = minLength; i < variables.length; i++) {
      _environment.setLocalVariable(variables[i], sassNull, nodeWithSpan);
    }
  }

  Future<Value> visitErrorRule(ErrorRule node) async {
    throw _exception(
        (await node.expression.accept(this)).toString(), node.span);
  }

  Future<Value?> visitExtendRule(ExtendRule node) async {
    var styleRule = _styleRule;
    if (styleRule == null || _declarationName != null) {
      throw _exception(
          "@extend may only be used within style rules.", node.span);
    }

    var targetText =
        await _interpolationToValue(node.selector, warnForColor: true);

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

      _extensionStore.addExtension(
          styleRule.selector, compound.components.first, node, _mediaQueries);
    }

    return null;
  }

  Future<Value?> visitAtRule(AtRule node) async {
    // NOTE: this logic is largely duplicated in [visitCssAtRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "At-rules may not be used within nested declarations.", node.span);
    }

    var name = await _interpolationToValue(node.name);

    var value = await node.value.andThen((value) =>
        _interpolationToValue(value, trim: true, warnForColor: true));

    var children = node.children;
    if (children == null) {
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

    await _withParent(ModifiableCssAtRule(name, node.span, value: value),
        () async {
      var styleRule = _styleRule;
      if (styleRule == null || _inKeyframes) {
        for (var child in children) {
          await child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the at-rule so that
        // declarations immediately inside it have somewhere to go.
        //
        // For example, "a {@foo {b: c}}" should produce "@foo {a {b: c}}".
        await _withParent(styleRule.copyWithoutChildren(), () async {
          for (var child in children) {
            await child.accept(this);
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

  Future<Value?> visitForRule(ForRule node) async {
    var fromNumber = await _addExceptionSpanAsync(
        node.from, () async => (await node.from.accept(this)).assertNumber());
    var toNumber = await _addExceptionSpanAsync(
        node.to, () async => (await node.to.accept(this)).assertNumber());

    var from = _addExceptionSpan(node.from, () => fromNumber.assertInt());
    var to = _addExceptionSpan(
        node.to,
        () => toNumber
            .coerce(fromNumber.numeratorUnits, fromNumber.denominatorUnits)
            .assertInt());

    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return null;

    return _environment.scope(() async {
      var nodeWithSpan = _expressionNode(node.from);
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(
            node.variable,
            SassNumber.withUnits(i,
                numeratorUnits: fromNumber.numeratorUnits,
                denominatorUnits: fromNumber.denominatorUnits),
            nodeWithSpan);
        var result = await _handleReturn<Statement>(
            node.children, (child) => child.accept(this));
        if (result != null) return result;
      }
      return null;
    }, semiGlobal: true);
  }

  Future<Value?> visitForwardRule(ForwardRule node) async {
    var oldConfiguration = _configuration;
    var adjustedConfiguration = oldConfiguration.throughForward(node);

    if (node.configuration.isNotEmpty) {
      var newConfiguration =
          await _addForwardConfiguration(adjustedConfiguration, node);

      await _loadModule(node.url, "@forward", node, (module) {
        _environment.forwardModule(module, node);
      }, configuration: newConfiguration);

      _removeUsedConfiguration(adjustedConfiguration, newConfiguration,
          except: {
            for (var variable in node.configuration)
              if (!variable.isGuarded) variable.name
          });

      // Remove all the variables that weren't configured by this particular
      // `@forward` before checking that the configuration is empty. Errors for
      // outer `with` clauses will be thrown once those clauses finish
      // executing.
      var configuredVariables = {
        for (var variable in node.configuration) variable.name
      };
      for (var name in newConfiguration.values.keys.toList()) {
        if (!configuredVariables.contains(name)) newConfiguration.remove(name);
      }

      _assertConfigurationIsEmpty(newConfiguration);
    } else {
      _configuration = adjustedConfiguration;
      await _loadModule(node.url, "@forward", node, (module) {
        _environment.forwardModule(module, node);
      });
      _configuration = oldConfiguration;
    }

    return null;
  }

  /// Updates [configuration] to include [node]'s configuration and returns the
  /// result.
  Future<Configuration> _addForwardConfiguration(
      Configuration configuration, ForwardRule node) async {
    var newValues = Map.of(configuration.values);
    for (var variable in node.configuration) {
      if (variable.isGuarded) {
        var oldValue = configuration.remove(variable.name);
        if (oldValue != null && oldValue.value != sassNull) {
          newValues[variable.name] = oldValue;
          continue;
        }
      }

      var variableNodeWithSpan = _expressionNode(variable.expression);
      newValues[variable.name] = ConfiguredValue.explicit(
          _withoutSlash(
              await variable.expression.accept(this), variableNodeWithSpan),
          variable.span,
          variableNodeWithSpan);
    }

    if (configuration is ExplicitConfiguration || configuration.isEmpty) {
      return ExplicitConfiguration(newValues, node);
    } else {
      return Configuration.implicit(newValues);
    }
  }

  /// Remove configured values from [upstream] that have been removed from
  /// [downstream], unless they match a name in [except].
  void _removeUsedConfiguration(
      Configuration upstream, Configuration downstream,
      {required Set<String> except}) {
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
      {bool nameInError = false}) {
    // By definition, implicit configurations are allowed to only use a subset
    // of their values.
    if (configuration is! ExplicitConfiguration) return;
    if (configuration.isEmpty) return;

    var entry = configuration.values.entries.first;
    throw _exception(
        nameInError
            ? "\$${entry.key} was not declared with !default in the @used "
                "module."
            : "This variable was not declared with !default in the @used "
                "module.",
        entry.value.configurationSpan);
  }

  Future<Value?> visitFunctionRule(FunctionRule node) async {
    _environment.setFunction(UserDefinedCallable(node, _environment.closure()));
    return null;
  }

  Future<Value?> visitIfRule(IfRule node) async {
    IfRuleClause? clause = node.lastClause;
    for (var clauseToCheck in node.clauses) {
      if ((await clauseToCheck.expression.accept(this)).isTruthy) {
        clause = clauseToCheck;
        break;
      }
    }
    if (clause == null) return null;

    return await _environment.scope(
        () => _handleReturn<Statement>(
            clause!.children, // dart-lang/sdk#45348
            (child) => child.accept(this)),
        semiGlobal: true,
        when: clause.hasDeclarations);
  }

  Future<Value?> visitImportRule(ImportRule node) async {
    for (var import in node.imports) {
      if (import is DynamicImport) {
        await _visitDynamicImport(import);
      } else {
        await _visitStaticImport(import as StaticImport);
      }
    }
    return null;
  }

  /// Adds the stylesheet imported by [import] to the current document.
  Future<void> _visitDynamicImport(DynamicImport import) {
    return _withStackFrame("@import", import, () async {
      var result =
          await _loadStylesheet(import.urlString, import.span, forImport: true);
      var stylesheet = result.stylesheet;

      var url = stylesheet.span.sourceUrl;
      if (url != null) {
        if (_activeModules.containsKey(url)) {
          throw _activeModules[url].andThen((previousLoad) =>
                  _multiSpanException("This file is already being loaded.",
                      "new load", {previousLoad.span: "original load"})) ??
              _exception("This file is already being loaded.");
        }
        _activeModules[url] = import;
      }

      // If the imported stylesheet doesn't use any modules, we can inject its
      // CSS directly into the current stylesheet. If it does use modules, we
      // need to put its CSS into an intermediate [ModifiableCssStylesheet] so
      // that we can hermetically resolve `@extend`s before injecting it.
      if (stylesheet.uses.isEmpty && stylesheet.forwards.isEmpty) {
        var oldImporter = _importer;
        var oldStylesheet = _stylesheet;
        var oldInDependency = _inDependency;
        _importer = result.importer;
        _stylesheet = stylesheet;
        _inDependency = result.isDependency;
        await visitStylesheet(stylesheet);
        _importer = oldImporter;
        _stylesheet = oldStylesheet;
        _inDependency = oldInDependency;
        _activeModules.remove(url);
        return;
      }

      // If only built-in modules are loaded, we still need a separate
      // environment to ensure their namespaces aren't exposed in the outer
      // environment, but we don't need to worry about `@extend`s, so we can
      // add styles directly to the existing stylesheet instead of creating a
      // new one.
      var loadsUserDefinedModules =
          stylesheet.uses.any((rule) => rule.url.scheme != 'sass') ||
              stylesheet.forwards.any((rule) => rule.url.scheme != 'sass');

      late List<ModifiableCssNode> children;
      var environment = _environment.forImport();
      await _withEnvironment(environment, () async {
        var oldImporter = _importer;
        var oldStylesheet = _stylesheet;
        var oldRoot = _root;
        var oldParent = _parent;
        var oldEndOfImports = _endOfImports;
        var oldOutOfOrderImports = _outOfOrderImports;
        var oldConfiguration = _configuration;
        var oldInDependency = _inDependency;
        _importer = result.importer;
        _stylesheet = stylesheet;
        if (loadsUserDefinedModules) {
          _root = ModifiableCssStylesheet(stylesheet.span);
          _parent = _root;
          _endOfImports = 0;
          _outOfOrderImports = null;
        }
        _inDependency = result.isDependency;

        // This configuration is only used if it passes through a `@forward`
        // rule, so we avoid creating unnecessary ones for performance reasons.
        if (stylesheet.forwards.isNotEmpty) {
          _configuration = environment.toImplicitConfiguration();
        }

        await visitStylesheet(stylesheet);
        children = loadsUserDefinedModules ? _addOutOfOrderImports() : [];

        _importer = oldImporter;
        _stylesheet = oldStylesheet;
        _root = oldRoot;
        _parent = oldParent;
        _endOfImports = oldEndOfImports;
        _outOfOrderImports = oldOutOfOrderImports;
        _configuration = oldConfiguration;
        _inDependency = oldInDependency;
      });

      // Create a dummy module with empty CSS and no extensions to make forwarded
      // members available in the current import context and to combine all the
      // CSS from modules used by [stylesheet].
      var module = environment.toDummyModule();
      _environment.importForwards(module);

      if (loadsUserDefinedModules) {
        if (module.transitivelyContainsCss) {
          // If any transitively used module contains extensions, we need to
          // clone all modules' CSS. Otherwise, it's possible that they'll be
          // used or imported from another location that shouldn't have the same
          // extensions applied.
          await _combineCss(module,
                  clone: module.transitivelyContainsExtensions)
              .accept(this);
        }

        var visitor = _ImportedCssVisitor(this);
        for (var child in children) {
          child.accept(visitor);
        }
      }

      _activeModules.remove(url);
    });
  }

  /// Loads the [Stylesheet] identified by [url], or throws a
  /// [SassRuntimeException] if loading fails.
  ///
  /// This first tries loading [url] relative to [baseUrl], which defaults to
  /// `_stylesheet.span.sourceUrl`.
  Future<_LoadedStylesheet> _loadStylesheet(String url, FileSpan span,
      {Uri? baseUrl, bool forImport = false}) async {
    try {
      assert(_importSpan == null);
      _importSpan = span;

      var importCache = _importCache;
      if (importCache != null) {
        baseUrl ??= _stylesheet.span.sourceUrl;
        var tuple = await importCache.canonicalize(Uri.parse(url),
            baseImporter: _importer, baseUrl: baseUrl, forImport: forImport);

        if (tuple != null) {
          var isDependency = _inDependency || tuple.item1 != _importer;
          var stylesheet = await importCache.importCanonical(
              tuple.item1, tuple.item2,
              originalUrl: tuple.item3, quiet: _quietDeps && isDependency);
          if (stylesheet != null) {
            _loadedUrls.add(tuple.item2);
            return _LoadedStylesheet(stylesheet,
                importer: tuple.item1, isDependency: isDependency);
          }
        }
      } else {
        var result = await _importLikeNode(url, forImport);
        if (result != null) {
          result.stylesheet.span.sourceUrl.andThen(_loadedUrls.add);
          return result;
        }
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
      String? message;
      try {
        message = (error as dynamic).message as String;
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
  Future<_LoadedStylesheet?> _importLikeNode(
      String originalUrl, bool forImport) async {
    var result = _nodeImporter!
        .loadRelative(originalUrl, _stylesheet.span.sourceUrl, forImport);

    bool isDependency;
    if (result != null) {
      isDependency = _inDependency;
    } else {
      result = await _nodeImporter!
          .loadAsync(originalUrl, _stylesheet.span.sourceUrl, forImport);
      if (result == null) return null;
      isDependency = true;
    }

    var contents = result.item1;
    var url = result.item2;

    return _LoadedStylesheet(
        Stylesheet.parse(contents,
            url.startsWith('file') ? Syntax.forPath(url) : Syntax.scss,
            url: url,
            logger: _quietDeps && isDependency ? Logger.quiet : _logger),
        isDependency: isDependency);
  }

  /// Adds a CSS import for [import].
  Future<void> _visitStaticImport(StaticImport import) async {
    // NOTE: this logic is largely duplicated in [visitCssImport]. Most changes
    // here should be mirrored there.

    var url = await _interpolationToValue(import.url);
    var supports = await import.supports.andThen((supports) async {
      var arg = supports is SupportsDeclaration
          ? "${await _evaluateToCss(supports.name)}: "
              "${await _evaluateToCss(supports.value)}"
          : await supports.andThen(_visitSupportsCondition);
      return CssValue("supports($arg)", supports.span);
    });
    var rawMedia = import.media;
    var mediaQuery = await rawMedia.andThen(_visitMediaQueries);

    var node = ModifiableCssImport(url, import.span,
        supports: supports, media: mediaQuery);

    if (_parent != _root) {
      _parent.addChild(node);
    } else if (_endOfImports == _root.children.length) {
      _root.addChild(node);
      _endOfImports++;
    } else {
      (_outOfOrderImports ??= []).add(node);
    }
    return null;
  }

  Future<Value?> visitIncludeRule(IncludeRule node) async {
    var mixin = _addExceptionSpan(node,
        () => _environment.getMixin(node.name, namespace: node.namespace));
    if (mixin == null) {
      throw _exception("Undefined mixin.", node.span);
    }

    var nodeWithSpan = AstNode.fake(() => node.spanWithoutContent);
    if (mixin is AsyncBuiltInCallable) {
      if (node.content != null) {
        throw _exception("Mixin doesn't accept a content block.", node.span);
      }

      await _runBuiltInCallable(node.arguments, mixin, nodeWithSpan);
    } else if (mixin is UserDefinedCallable<AsyncEnvironment>) {
      if (node.content != null &&
          !(mixin.declaration as MixinRule).hasContent) {
        throw MultiSpanSassRuntimeException(
            "Mixin doesn't accept a content block.",
            node.spanWithoutContent,
            "invocation",
            {mixin.declaration.arguments.spanWithName: "declaration"},
            _stackTrace(node.spanWithoutContent));
      }

      var contentCallable = node.content.andThen(
          (content) => UserDefinedCallable(content, _environment.closure()));
      await _runUserDefinedCallable(node.arguments, mixin, nodeWithSpan,
          () async {
        await _environment.withContent(contentCallable, () async {
          await _environment.asMixin(() async {
            for (var statement in mixin.declaration.children) {
              await _addErrorSpan(nodeWithSpan, () => statement.accept(this));
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

  Future<Value?> visitMixinRule(MixinRule node) async {
    _environment.setMixin(UserDefinedCallable(node, _environment.closure()));
    return null;
  }

  Future<Value?> visitLoudComment(LoudComment node) async {
    // NOTE: this logic is largely duplicated in [visitCssComment]. Most changes
    // here should be mirrored there.

    if (_inFunction) return null;

    // Comments are allowed to appear between CSS imports.
    if (_parent == _root && _endOfImports == _root.children.length) {
      _endOfImports++;
    }

    _parent.addChild(ModifiableCssComment(
        await _performInterpolation(node.text), node.span));
    return null;
  }

  Future<Value?> visitMediaRule(MediaRule node) async {
    // NOTE: this logic is largely duplicated in [visitCssMediaRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var queries = await _visitMediaQueries(node.query);
    var mergedQueries = _mediaQueries
        .andThen((mediaQueries) => _mergeMediaQueries(mediaQueries, queries));
    if (mergedQueries != null && mergedQueries.isEmpty) return null;

    await _withParent(
        ModifiableCssMediaRule(mergedQueries ?? queries, node.span), () async {
      await _withMediaQueries(mergedQueries ?? queries, () async {
        var styleRule = _styleRule;
        if (styleRule == null) {
          for (var child in node.children) {
            await child.accept(this);
          }
        } else {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          await _withParent(styleRule.copyWithoutChildren(), () async {
            for (var child in node.children) {
              await child.accept(this);
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
  Future<List<CssMediaQuery>> _visitMediaQueries(
      Interpolation interpolation) async {
    var resolved =
        await _performInterpolation(interpolation, warnForColor: true);

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
  List<CssMediaQuery>? _mergeMediaQueries(
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

  Future<Value> visitReturnRule(ReturnRule node) async =>
      _withoutSlash(await node.expression.accept(this), node.expression);

  Future<Value?> visitSilentComment(SilentComment node) async => null;

  Future<Value?> visitStyleRule(StyleRule node) async {
    // NOTE: this logic is largely duplicated in [visitCssStyleRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var selectorText = await _interpolationToValue(node.selector,
        trim: true, warnForColor: true);
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
      await _withParent(rule, () async {
        for (var child in node.children) {
          await child.accept(this);
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
            _styleRuleIgnoringAtRoot?.originalSelector,
            implicitParent: !_atRootExcludingStyleRule));

    var selector = _extensionStore.addSelector(
        parsedSelector, node.selector.span, _mediaQueries);
    var rule = ModifiableCssStyleRule(selector, node.span,
        originalSelector: parsedSelector);
    var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
    _atRootExcludingStyleRule = false;
    await _withParent(rule, () async {
      await _withStyleRule(rule, () async {
        for (var child in node.children) {
          await child.accept(this);
        }
      });
    },
        through: (node) => node is CssStyleRule,
        scopeWhen: node.hasDeclarations);
    _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;

    if (_styleRule == null && _parent.children.isNotEmpty) {
      var lastChild = _parent.children.last;
      lastChild.isGroupEnd = true;
    }

    return null;
  }

  Future<Value?> visitSupportsRule(SupportsRule node) async {
    // NOTE: this logic is largely duplicated in [visitCssSupportsRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Supports rules may not be used within nested declarations.",
          node.span);
    }

    var condition = CssValue(
        await _visitSupportsCondition(node.condition), node.condition.span);
    await _withParent(ModifiableCssSupportsRule(condition, node.span),
        () async {
      var styleRule = _styleRule;
      if (styleRule == null) {
        for (var child in node.children) {
          await child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the supports rule so that
        // declarations immediately inside @supports have somewhere to go.
        //
        // For example, "a {@supports (a: b) {b: c}}" should produce "@supports
        // (a: b) {a {b: c}}".
        await _withParent(styleRule.copyWithoutChildren(), () async {
          for (var child in node.children) {
            await child.accept(this);
          }
        });
      }
    },
        through: (node) => node is CssStyleRule,
        scopeWhen: node.hasDeclarations);

    return null;
  }

  /// Evaluates [condition] and converts it to a plain CSS string.
  Future<String> _visitSupportsCondition(SupportsCondition condition) async {
    if (condition is SupportsOperation) {
      return "${await _parenthesize(condition.left, condition.operator)} "
          "${condition.operator} "
          "${await _parenthesize(condition.right, condition.operator)}";
    } else if (condition is SupportsNegation) {
      return "not ${await _parenthesize(condition.condition)}";
    } else if (condition is SupportsInterpolation) {
      return await _evaluateToCss(condition.expression, quote: false);
    } else if (condition is SupportsDeclaration) {
      return "(${await _evaluateToCss(condition.name)}: "
          "${await _evaluateToCss(condition.value)})";
    } else if (condition is SupportsFunction) {
      return "${await _performInterpolation(condition.name)}("
          "${await _performInterpolation(condition.arguments)})";
    } else if (condition is SupportsAnything) {
      return "(${await _performInterpolation(condition.contents)})";
    } else {
      throw ArgumentError(
          "Unknown supports condition type ${condition.runtimeType}.");
    }
  }

  /// Evaluates [condition] and converts it to a plain CSS string, with
  /// parentheses if necessary.
  ///
  /// If [operator] is passed, it's the operator for the surrounding
  /// [SupportsOperation], and is used to determine whether parentheses are
  /// necessary if [condition] is also a [SupportsOperation].
  Future<String> _parenthesize(SupportsCondition condition,
      [String? operator]) async {
    if ((condition is SupportsNegation) ||
        (condition is SupportsOperation &&
            (operator == null || operator != condition.operator))) {
      return "(${await _visitSupportsCondition(condition)})";
    } else {
      return await _visitSupportsCondition(condition);
    }
  }

  Future<Value?> visitVariableDeclaration(VariableDeclaration node) async {
    if (node.isGuarded) {
      if (node.namespace == null && _environment.atRoot) {
        var override = _configuration.remove(node.name);
        if (override != null && override.value != sassNull) {
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
      _warn(
          _environment.atRoot
              ? "As of Dart Sass 2.0.0, !global assignments won't be able to "
                  "declare new variables.\n"
                  "\n"
                  "Since this assignment is at the root of the stylesheet, the "
                  "!global flag is\n"
                  "unnecessary and can safely be removed."
              : "As of Dart Sass 2.0.0, !global assignments won't be able to "
                  "declare new variables.\n"
                  "\n"
                  "Recommendation: add `${node.originalName}: null` at the "
                  "stylesheet root.",
          node.span,
          deprecation: true);
    }

    var value =
        _withoutSlash(await node.expression.accept(this), node.expression);
    _addExceptionSpan(node, () {
      _environment.setVariable(
          node.name, value, _expressionNode(node.expression),
          namespace: node.namespace, global: node.isGlobal);
    });
    return null;
  }

  Future<Value?> visitUseRule(UseRule node) async {
    var configuration = const Configuration.empty();
    if (node.configuration.isNotEmpty) {
      var values = <String, ConfiguredValue>{};
      for (var variable in node.configuration) {
        var variableNodeWithSpan = _expressionNode(variable.expression);
        values[variable.name] = ConfiguredValue.explicit(
            _withoutSlash(
                await variable.expression.accept(this), variableNodeWithSpan),
            variable.span,
            variableNodeWithSpan);
      }
      configuration = ExplicitConfiguration(values, node);
    }

    await _loadModule(node.url, "@use", node, (module) {
      _environment.addModule(module, node, namespace: node.namespace);
    }, configuration: configuration);
    _assertConfigurationIsEmpty(configuration);

    return null;
  }

  Future<Value?> visitWarnRule(WarnRule node) async {
    var value =
        await _addExceptionSpanAsync(node, () => node.expression.accept(this));
    _logger.warn(
        value is SassString ? value.text : _serialize(value, node.expression),
        trace: _stackTrace(node.span));
    return null;
  }

  Future<Value?> visitWhileRule(WhileRule node) {
    return _environment.scope(() async {
      while ((await node.condition.accept(this)).isTruthy) {
        var result = await _handleReturn<Statement>(
            node.children, (child) => child.accept(this));
        if (result != null) return result;
      }
      return null;
    }, semiGlobal: true, when: node.hasDeclarations);
  }

  // ## Expressions

  Future<Value> visitBinaryOperationExpression(BinaryOperationExpression node) {
    return _addExceptionSpanAsync(node, () async {
      var left = await node.left.accept(this);
      switch (node.operator) {
        case BinaryOperator.singleEquals:
          var right = await node.right.accept(this);
          return left.singleEquals(right);

        case BinaryOperator.or:
          return left.isTruthy ? left : await node.right.accept(this);

        case BinaryOperator.and:
          return left.isTruthy ? await node.right.accept(this) : left;

        case BinaryOperator.equals:
          var right = await node.right.accept(this);
          return SassBoolean(left == right);

        case BinaryOperator.notEquals:
          var right = await node.right.accept(this);
          return SassBoolean(left != right);

        case BinaryOperator.greaterThan:
          var right = await node.right.accept(this);
          return left.greaterThan(right);

        case BinaryOperator.greaterThanOrEquals:
          var right = await node.right.accept(this);
          return left.greaterThanOrEquals(right);

        case BinaryOperator.lessThan:
          var right = await node.right.accept(this);
          return left.lessThan(right);

        case BinaryOperator.lessThanOrEquals:
          var right = await node.right.accept(this);
          return left.lessThanOrEquals(right);

        case BinaryOperator.plus:
          var right = await node.right.accept(this);
          return left.plus(right);

        case BinaryOperator.minus:
          var right = await node.right.accept(this);
          return left.minus(right);

        case BinaryOperator.times:
          var right = await node.right.accept(this);
          return left.times(right);

        case BinaryOperator.dividedBy:
          var right = await node.right.accept(this);
          var result = left.dividedBy(right);
          if (node.allowsSlash && left is SassNumber && right is SassNumber) {
            return (result as SassNumber).withSlash(left, right);
          } else {
            if (left is SassNumber && right is SassNumber) {
              String recommendation(Expression expression) {
                if (expression is BinaryOperationExpression &&
                    expression.operator == BinaryOperator.dividedBy) {
                  return "math.div(${recommendation(expression.left)}, "
                      "${recommendation(expression.right)})";
                } else {
                  return expression.toString();
                }
              }

              _warn(
                  "Using / for division is deprecated and will be removed in "
                  "Dart Sass 2.0.0.\n"
                  "\n"
                  "Recommendation: ${recommendation(node)}\n"
                  "\n"
                  "More info and automated migrator: "
                  "https://sass-lang.com/d/slash-div",
                  node.span,
                  deprecation: true);
            }

            return result;
          }

        case BinaryOperator.modulo:
          var right = await node.right.accept(this);
          return left.modulo(right);

        default:
          throw ArgumentError("Unknown binary operator ${node.operator}.");
      }
    });
  }

  Future<Value> visitValueExpression(ValueExpression node) async => node.value;

  Future<Value> visitVariableExpression(VariableExpression node) async {
    var result = _addExceptionSpan(node,
        () => _environment.getVariable(node.name, namespace: node.namespace));
    if (result != null) return result;
    throw _exception("Undefined variable.", node.span);
  }

  Future<Value> visitUnaryOperationExpression(
      UnaryOperationExpression node) async {
    var operand = await node.operand.accept(this);
    return _addExceptionSpan(node, () {
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
    });
  }

  Future<SassBoolean> visitBooleanExpression(BooleanExpression node) async =>
      SassBoolean(node.value);

  Future<Value> visitIfExpression(IfExpression node) async {
    var pair = await _evaluateMacroArguments(node);
    var positional = pair.item1;
    var named = pair.item2;

    _verifyArguments(positional.length, named, IfExpression.declaration, node);

    // ignore: prefer_is_empty
    var condition = positional.length > 0 ? positional[0] : named["condition"]!;
    var ifTrue = positional.length > 1 ? positional[1] : named["if-true"]!;
    var ifFalse = positional.length > 2 ? positional[2] : named["if-false"]!;

    var result = (await condition.accept(this)).isTruthy ? ifTrue : ifFalse;
    return _withoutSlash(await result.accept(this), _expressionNode(result));
  }

  Future<Value> visitNullExpression(NullExpression node) async => sassNull;

  Future<SassNumber> visitNumberExpression(NumberExpression node) async =>
      SassNumber(node.value, node.unit);

  Future<Value> visitParenthesizedExpression(ParenthesizedExpression node) =>
      node.expression.accept(this);

  Future<Value> visitCalculationExpression(CalculationExpression node) async {
    var arguments = [
      for (var argument in node.arguments)
        await _visitCalculationValue(argument,
            inMinMax: node.name == 'min' || node.name == 'max')
    ];

    try {
      switch (node.name) {
        case "calc":
          assert(arguments.length == 1);
          return SassCalculation.calc(arguments[0]);
        case "min":
          return SassCalculation.min(arguments);
        case "max":
          return SassCalculation.max(arguments);
        case "clamp":
          return SassCalculation.clamp(
              arguments[0],
              arguments.length > 1 ? arguments[1] : null,
              arguments.length > 2 ? arguments[2] : null);
        default:
          throw UnsupportedError('Unknown calculation name "${node.name}".');
      }
    } on SassScriptException catch (error) {
      // The simplification logic in the [SassCalculation] static methods will
      // throw an error if the arguments aren't compatible, but we have access
      // to the original spans so we can throw a more informative error.
      _verifyCompatibleNumbers(arguments, node.arguments);
      throw _exception(error.message, node.span);
    }
  }

  /// Verifies that [args] all have compatible units that can be used for CSS
  /// calculations, and throws a [SassException] if not.
  ///
  /// The [nodesWithSpans] should correspond to the spans for [args].
  void _verifyCompatibleNumbers(
      List<Object> args, List<AstNode> nodesWithSpans) {
    // Note: this logic is largely duplicated in
    // SassCalculation._verifyCompatibleNumbers and most changes here should
    // also be reflected there.
    for (var i = 0; i < args.length; i++) {
      var arg = args[i];
      if (arg is! SassNumber) continue;
      if (arg.numeratorUnits.length > 1 || arg.denominatorUnits.isNotEmpty) {
        throw _exception("Number $arg isn't compatible with CSS calculations.",
            nodesWithSpans[i].span);
      }
    }

    for (var i = 0; i < args.length - 1; i++) {
      var number1 = args[i];
      if (number1 is! SassNumber) continue;

      for (var j = i + 1; j < args.length; j++) {
        var number2 = args[j];
        if (number2 is! SassNumber) continue;
        if (number1.hasPossiblyCompatibleUnits(number2)) continue;

        throw MultiSpanSassRuntimeException(
            "$number1 and $number2 are incompatible.",
            nodesWithSpans[i].span,
            number1.toString(),
            {nodesWithSpans[j].span: number2.toString()},
            _stackTrace(nodesWithSpans[i].span));
      }
    }
  }

  /// Evaluates [node] as a component of a calculation.
  ///
  /// If [inMinMax] is `true`, this allows unitless numbers to be added and
  /// subtracted with numbers with units, for backwards-compatibility with the
  /// old global `min()` and `max()` functions.
  Future<Object> _visitCalculationValue(Expression node,
      {required bool inMinMax}) async {
    if (node is ParenthesizedExpression) {
      var inner = node.expression;
      var result = await _visitCalculationValue(inner, inMinMax: inMinMax);
      return inner is FunctionExpression &&
              inner.name.toLowerCase() == 'var' &&
              result is SassString &&
              !result.hasQuotes
          ? SassString('(${result.text})', quotes: false)
          : result;
    } else if (node is StringExpression) {
      assert(!node.hasQuotes);
      return CalculationInterpolation(await _performInterpolation(node.text));
    } else if (node is BinaryOperationExpression) {
      return await _addExceptionSpanAsync(
          node,
          () async => SassCalculation.operateInternal(
              _binaryOperatorToCalculationOperator(node.operator),
              await _visitCalculationValue(node.left, inMinMax: inMinMax),
              await _visitCalculationValue(node.right, inMinMax: inMinMax),
              inMinMax: inMinMax));
    } else {
      assert(node is NumberExpression ||
          node is CalculationExpression ||
          node is VariableExpression ||
          node is FunctionExpression ||
          node is IfExpression);
      var result = await node.accept(this);
      if (result is SassNumber || result is SassCalculation) return result;
      if (result is SassString && !result.hasQuotes) return result;
      throw _exception(
          "Value $result can't be used in a calculation.", node.span);
    }
  }

  /// Returns the [CalculationOperator] that corresponds to [operator].
  CalculationOperator _binaryOperatorToCalculationOperator(
      BinaryOperator operator) {
    switch (operator) {
      case BinaryOperator.plus:
        return CalculationOperator.plus;
      case BinaryOperator.minus:
        return CalculationOperator.minus;
      case BinaryOperator.times:
        return CalculationOperator.times;
      case BinaryOperator.dividedBy:
        return CalculationOperator.dividedBy;
      default:
        throw UnsupportedError("Invalid calculation operator $operator.");
    }
  }

  Future<SassColor> visitColorExpression(ColorExpression node) async =>
      node.value;

  Future<SassList> visitListExpression(ListExpression node) async => SassList(
      await mapAsync(
          node.contents, (Expression expression) => expression.accept(this)),
      node.separator,
      brackets: node.hasBrackets);

  Future<SassMap> visitMapExpression(MapExpression node) async {
    var map = <Value, Value>{};
    var keyNodes = <Value, AstNode>{};
    for (var pair in node.pairs) {
      var keyValue = await pair.item1.accept(this);
      var valueValue = await pair.item2.accept(this);

      var oldValue = map[keyValue];
      if (oldValue != null) {
        var oldValueSpan = keyNodes[keyValue]?.span;
        throw MultiSpanSassRuntimeException(
            'Duplicate key.',
            pair.item1.span,
            'second key',
            {if (oldValueSpan != null) oldValueSpan: 'first key'},
            _stackTrace(pair.item1.span));
      }
      map[keyValue] = valueValue;
      keyNodes[keyValue] = pair.item1;
    }
    return SassMap(map);
  }

  Future<Value> visitFunctionExpression(FunctionExpression node) async {
    var function = _addExceptionSpan(
        node, () => _getFunction(node.name, namespace: node.namespace));

    if (function == null) {
      if (node.namespace != null) {
        throw _exception("Undefined function.", node.span);
      }

      function = PlainCssCallable(node.originalName);
    }

    var oldInFunction = _inFunction;
    _inFunction = true;
    var result = await _addErrorSpan(
        node, () => _runFunctionCallable(node.arguments, function, node));
    _inFunction = oldInFunction;
    return result;
  }

  Future<Value> visitInterpolatedFunctionExpression(
      InterpolatedFunctionExpression node) async {
    var function = PlainCssCallable(await _performInterpolation(node.name));
    var oldInFunction = _inFunction;
    _inFunction = true;
    var result = await _addErrorSpan(
        node, () => _runFunctionCallable(node.arguments, function, node));
    _inFunction = oldInFunction;
    return result;
  }

  /// Like `_environment.getFunction`, but also returns built-in
  /// globally-available functions.
  AsyncCallable? _getFunction(String name, {String? namespace}) {
    var local = _environment.getFunction(name, namespace: namespace);
    if (local != null || namespace != null) return local;
    return _builtInFunctions[name];
  }

  /// Evaluates the arguments in [arguments] as applied to [callable], and
  /// invokes [run] in a scope with those arguments defined.
  Future<V> _runUserDefinedCallable<V extends Value?>(
      ArgumentInvocation arguments,
      UserDefinedCallable<AsyncEnvironment> callable,
      AstNode nodeWithSpan,
      Future<V> run()) async {
    // TODO(nweiz): Set [trackSpans] to `null` once we're no longer emitting
    // deprecation warnings for /-as-division.
    var evaluated = await _evaluateArguments(arguments);

    var name = callable.name;
    if (name != "@content") name += "()";

    return await _withStackFrame(name, nodeWithSpan, () {
      // Add an extra closure() call so that modifications to the environment
      // don't affect the underlying environment closure.
      return _withEnvironment(callable.environment.closure(), () {
        return _environment.scope(() async {
          _verifyArguments(evaluated.positional.length, evaluated.named,
              callable.declaration.arguments, nodeWithSpan);

          var declaredArguments = callable.declaration.arguments.arguments;
          var minLength =
              math.min(evaluated.positional.length, declaredArguments.length);
          for (var i = 0; i < minLength; i++) {
            _environment.setLocalVariable(declaredArguments[i].name,
                evaluated.positional[i], evaluated.positionalNodes[i]);
          }

          for (var i = evaluated.positional.length;
              i < declaredArguments.length;
              i++) {
            var argument = declaredArguments[i];
            var value = evaluated.named.remove(argument.name) ??
                _withoutSlash(
                    await argument.defaultValue!.accept<Future<Value>>(this),
                    _expressionNode(argument.defaultValue!));
            _environment.setLocalVariable(
                argument.name,
                value,
                evaluated.namedNodes[argument.name] ??
                    _expressionNode(argument.defaultValue!));
          }

          SassArgumentList? argumentList;
          var restArgument = callable.declaration.arguments.restArgument;
          if (restArgument != null) {
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
                restArgument, argumentList, nodeWithSpan);
          }

          var result = await run();

          if (argumentList == null) return result;
          if (evaluated.named.isEmpty) return result;
          if (argumentList.wereKeywordsAccessed) return result;

          var argumentWord = pluralize('argument', evaluated.named.keys.length);
          var argumentNames =
              toSentence(evaluated.named.keys.map((name) => "\$$name"), 'or');
          throw MultiSpanSassRuntimeException(
              "No $argumentWord named $argumentNames.",
              nodeWithSpan.span,
              "invocation",
              {callable.declaration.arguments.spanWithName: "declaration"},
              _stackTrace(nodeWithSpan.span));
        });
      });
    });
  }

  /// Evaluates [arguments] as applied to [callable].
  Future<Value> _runFunctionCallable(ArgumentInvocation arguments,
      AsyncCallable? callable, AstNode nodeWithSpan) async {
    if (callable is AsyncBuiltInCallable) {
      return _withoutSlash(
          await _runBuiltInCallable(arguments, callable, nodeWithSpan),
          nodeWithSpan);
    } else if (callable is UserDefinedCallable<AsyncEnvironment>) {
      return await _runUserDefinedCallable(arguments, callable, nodeWithSpan,
          () async {
        for (var statement in callable.declaration.children) {
          var returnValue = await statement.accept(this);
          if (returnValue is Value) return returnValue;
        }

        throw _exception(
            "Function finished without @return.", callable.declaration.span);
      });
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

        buffer.write(await _evaluateToCss(argument));
      }

      var restArg = arguments.rest;
      if (restArg != null) {
        var rest = await restArg.accept(this);
        if (!first) buffer.write(", ");
        buffer.write(_serialize(rest, restArg));
      }
      buffer.writeCharCode($rparen);

      return SassString(buffer.toString(), quotes: false);
    } else {
      throw ArgumentError('Unknown callable type ${callable.runtimeType}.');
    }
  }

  /// Evaluates [invocation] as applied to [callable], and invokes [callable]'s
  /// body.
  Future<Value> _runBuiltInCallable(ArgumentInvocation arguments,
      AsyncBuiltInCallable callable, AstNode nodeWithSpan) async {
    var evaluated = await _evaluateArguments(arguments);

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
          _withoutSlash(await argument.defaultValue!.accept(this),
              argument.defaultValue!));
    }

    SassArgumentList? argumentList;
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
      result = await withCurrentCallableNode(
          nodeWithSpan, () => callback(evaluated.positional));
    } on SassRuntimeException {
      rethrow;
    } on MultiSpanSassScriptException catch (error) {
      throw MultiSpanSassRuntimeException(
          error.message,
          nodeWithSpan.span,
          error.primaryLabel,
          error.secondarySpans,
          _stackTrace(nodeWithSpan.span));
    } on MultiSpanSassException catch (error) {
      throw MultiSpanSassRuntimeException(error.message, error.span,
          error.primaryLabel, error.secondarySpans, _stackTrace(error.span));
    } catch (error) {
      String? message;
      try {
        message = (error as dynamic).message as String;
      } catch (_) {
        message = error.toString();
      }
      throw _exception(message, nodeWithSpan.span);
    }
    _callableNode = oldCallableNode;

    if (argumentList == null) return result;
    if (evaluated.named.isEmpty) return result;
    if (argumentList.wereKeywordsAccessed) return result;

    throw MultiSpanSassRuntimeException(
        "No ${pluralize('argument', evaluated.named.keys.length)} named "
            "${toSentence(evaluated.named.keys.map((name) => "\$$name"), 'or')}.",
        nodeWithSpan.span,
        "invocation",
        {overload.spanWithName: "declaration"},
        _stackTrace(nodeWithSpan.span));
  }

  /// Returns the evaluated values of the given [arguments].
  Future<_ArgumentResults> _evaluateArguments(
      ArgumentInvocation arguments) async {
    // TODO(nweiz): This used to avoid tracking source spans for arguments if
    // [_sourceMap]s was false or it was being called from
    // [_runBuiltInCallable]. We always have to track them now to produce better
    // warnings for /-as-division, but once those warnings are gone we should go
    // back to tracking conditionally.

    var positional = <Value>[];
    var positionalNodes = <AstNode>[];
    for (var expression in arguments.positional) {
      var nodeForSpan = _expressionNode(expression);
      positional.add(_withoutSlash(await expression.accept(this), nodeForSpan));
      positionalNodes.add(nodeForSpan);
    }

    var named = <String, Value>{};
    var namedNodes = <String, AstNode>{};
    for (var entry in arguments.named.entries) {
      var nodeForSpan = _expressionNode(entry.value);
      named[entry.key] =
          _withoutSlash(await entry.value.accept(this), nodeForSpan);
      namedNodes[entry.key] = nodeForSpan;
    }

    var restArgs = arguments.rest;
    if (restArgs == null) {
      return _ArgumentResults(positional, positionalNodes, named, namedNodes,
          ListSeparator.undecided);
    }

    var rest = await restArgs.accept(this);
    var restNodeForSpan = _expressionNode(restArgs);
    var separator = ListSeparator.undecided;
    if (rest is SassMap) {
      _addRestMap(named, rest, restArgs, (value) => value);
      namedNodes.addAll({
        for (var key in rest.contents.keys)
          (key as SassString).text: restNodeForSpan
      });
    } else if (rest is SassList) {
      positional.addAll(
          rest.asList.map((value) => _withoutSlash(value, restNodeForSpan)));
      positionalNodes.addAll(List.filled(rest.lengthAsList, restNodeForSpan));
      separator = rest.separator;

      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = _withoutSlash(value, restNodeForSpan);
          namedNodes[key] = restNodeForSpan;
        });
      }
    } else {
      positional.add(_withoutSlash(rest, restNodeForSpan));
      positionalNodes.add(restNodeForSpan);
    }

    var keywordRestArgs = arguments.keywordRest;
    if (keywordRestArgs == null) {
      return _ArgumentResults(
          positional, positionalNodes, named, namedNodes, separator);
    }

    var keywordRest = await keywordRestArgs.accept(this);
    var keywordRestNodeForSpan = _expressionNode(keywordRestArgs);
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, keywordRestArgs, (value) => value);
      namedNodes.addAll({
        for (var key in keywordRest.contents.keys)
          (key as SassString).text: keywordRestNodeForSpan
      });
      return _ArgumentResults(
          positional, positionalNodes, named, namedNodes, separator);
    } else {
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).",
          keywordRestArgs.span);
    }
  }

  /// Evaluates the arguments in [arguments] only as much as necessary to
  /// separate out positional and named arguments.
  ///
  /// Returns the arguments as expressions so that they can be lazily evaluated
  /// for macros such as `if()`.
  Future<Tuple2<List<Expression>, Map<String, Expression>>>
      _evaluateMacroArguments(CallableInvocation invocation) async {
    var restArgs_ = invocation.arguments.rest;
    if (restArgs_ == null) {
      return Tuple2(
          invocation.arguments.positional, invocation.arguments.named);
    }
    var restArgs = restArgs_; // dart-lang/sdk#45348

    var positional = invocation.arguments.positional.toList();
    var named = Map.of(invocation.arguments.named);
    var rest = await restArgs.accept(this);
    var restNodeForSpan = _expressionNode(restArgs);
    if (rest is SassMap) {
      _addRestMap(named, rest, invocation,
          (value) => ValueExpression(value, restArgs.span));
    } else if (rest is SassList) {
      positional.addAll(rest.asList.map((value) => ValueExpression(
          _withoutSlash(value, restNodeForSpan), restArgs.span)));
      if (rest is SassArgumentList) {
        rest.keywords.forEach((key, value) {
          named[key] = ValueExpression(
              _withoutSlash(value, restNodeForSpan), restArgs.span);
        });
      }
    } else {
      positional.add(
          ValueExpression(_withoutSlash(rest, restNodeForSpan), restArgs.span));
    }

    var keywordRestArgs_ = invocation.arguments.keywordRest;
    if (keywordRestArgs_ == null) return Tuple2(positional, named);
    var keywordRestArgs = keywordRestArgs_; // dart-lang/sdk#45348

    var keywordRest = await keywordRestArgs.accept(this);
    var keywordRestNodeForSpan = _expressionNode(keywordRestArgs);
    if (keywordRest is SassMap) {
      _addRestMap(
          named,
          keywordRest,
          invocation,
          (value) => ValueExpression(
              _withoutSlash(value, keywordRestNodeForSpan),
              keywordRestArgs.span));
      return Tuple2(positional, named);
    } else {
      throw _exception(
          "Variable keyword arguments must be a map (was $keywordRest).",
          keywordRestArgs.span);
    }
  }

  /// Adds the values in [map] to [values].
  ///
  /// Throws a [SassRuntimeException] associated with [nodeWithSpan]'s source
  /// span if any [map] keys aren't strings.
  ///
  /// If [convert] is passed, that's used to convert the map values to the value
  /// type for [values]. Otherwise, the [Value]s are used as-is.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  void _addRestMap<T>(Map<String, T> values, SassMap map, AstNode nodeWithSpan,
      T convert(Value value)) {
    var expressionNode = _expressionNode(nodeWithSpan);
    map.contents.forEach((key, value) {
      if (key is SassString) {
        values[key.text] = convert(_withoutSlash(value, expressionNode));
      } else {
        throw _exception(
            "Variable keyword argument map must have string keys.\n"
            "$key is not a string in $map.",
            nodeWithSpan.span);
      }
    });
  }

  /// Throws a [SassRuntimeException] if [positional] and [named] aren't valid
  /// when applied to [arguments].
  void _verifyArguments(int positional, Map<String, dynamic> named,
          ArgumentDeclaration arguments, AstNode nodeWithSpan) =>
      _addExceptionSpan(
          nodeWithSpan, () => arguments.verify(positional, MapKeySet(named)));

  Future<Value> visitSelectorExpression(SelectorExpression node) async =>
      _styleRuleIgnoringAtRoot?.originalSelector.asSassList ?? sassNull;

  Future<SassString> visitStringExpression(StringExpression node) async {
    // Don't use [performInterpolation] here because we need to get the raw text
    // from strings, rather than the semantic value.
    return SassString(
        (await mapAsync(node.text.contents, (value) async {
          if (value is String) return value;
          var expression = value as Expression;
          var result = await expression.accept(this);
          return result is SassString
              ? result.text
              : _serialize(result, expression, quote: false);
        }))
            .join(),
        quotes: node.hasQuotes);
  }

  // ## Plain CSS

  // These methods are used when evaluating CSS syntax trees from `@import`ed
  // stylesheets that themselves contain `@use` rules, and CSS included via the
  // `load-css()` function. When we load a module using one of these constructs,
  // we first convert it to CSS (we can't evaluate it as Sass directly because
  // it may be used elsewhere and it must only be evaluated once). Then we
  // execute that CSS more or less as though it were Sass (we can't inject it
  // into the stylesheet as-is because the `@import` may be nested in other
  // rules). That's what these rules implement.

  Future<void> visitCssAtRule(CssAtRule node) async {
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

    await _withParent(
        ModifiableCssAtRule(node.name, node.span, value: node.value), () async {
      // We don't have to check for an unknown at-rule in a style rule here,
      // because the previous compilation has already bubbled the at-rule to the
      // root.
      for (var child in node.children) {
        await child.accept(this);
      }
    }, through: (node) => node is CssStyleRule, scopeWhen: false);

    _inUnknownAtRule = wasInUnknownAtRule;
    _inKeyframes = wasInKeyframes;
  }

  Future<void> visitCssComment(CssComment node) async {
    // NOTE: this logic is largely duplicated in [visitLoudComment]. Most
    // changes here should be mirrored there.

    // Comments are allowed to appear between CSS imports.
    if (_parent == _root && _endOfImports == _root.children.length) {
      _endOfImports++;
    }

    _parent.addChild(ModifiableCssComment(node.text, node.span));
  }

  Future<void> visitCssDeclaration(CssDeclaration node) async {
    _parent.addChild(ModifiableCssDeclaration(node.name, node.value, node.span,
        parsedAsCustomProperty: node.isCustomProperty,
        valueSpanForMap: node.valueSpanForMap));
  }

  Future<void> visitCssImport(CssImport node) async {
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
      (_outOfOrderImports ??= []).add(modifiableNode);
    }
  }

  Future<void> visitCssKeyframeBlock(CssKeyframeBlock node) async {
    // NOTE: this logic is largely duplicated in [visitStyleRule]. Most changes
    // here should be mirrored there.

    var rule = ModifiableCssKeyframeBlock(node.selector, node.span);
    await _withParent(rule, () async {
      for (var child in node.children) {
        await child.accept(this);
      }
    }, through: (node) => node is CssStyleRule, scopeWhen: false);
  }

  Future<void> visitCssMediaRule(CssMediaRule node) async {
    // NOTE: this logic is largely duplicated in [visitMediaRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var mergedQueries = _mediaQueries.andThen(
        (mediaQueries) => _mergeMediaQueries(mediaQueries, node.queries));
    if (mergedQueries != null && mergedQueries.isEmpty) return null;

    await _withParent(
        ModifiableCssMediaRule(mergedQueries ?? node.queries, node.span),
        () async {
      await _withMediaQueries(mergedQueries ?? node.queries, () async {
        var styleRule = _styleRule;
        if (styleRule == null) {
          for (var child in node.children) {
            await child.accept(this);
          }
        } else {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          await _withParent(styleRule.copyWithoutChildren(), () async {
            for (var child in node.children) {
              await child.accept(this);
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

  Future<void> visitCssStyleRule(CssStyleRule node) async {
    // NOTE: this logic is largely duplicated in [visitStyleRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var styleRule = _styleRule;
    var originalSelector = node.selector.value.resolveParentSelectors(
        styleRule?.originalSelector,
        implicitParent: !_atRootExcludingStyleRule);
    var selector = _extensionStore.addSelector(
        originalSelector, node.selector.span, _mediaQueries);
    var rule = ModifiableCssStyleRule(selector, node.span,
        originalSelector: originalSelector);
    var oldAtRootExcludingStyleRule = _atRootExcludingStyleRule;
    _atRootExcludingStyleRule = false;
    await _withParent(rule, () async {
      await _withStyleRule(rule, () async {
        for (var child in node.children) {
          await child.accept(this);
        }
      });
    }, through: (node) => node is CssStyleRule, scopeWhen: false);
    _atRootExcludingStyleRule = oldAtRootExcludingStyleRule;

    if (styleRule == null && _parent.children.isNotEmpty) {
      var lastChild = _parent.children.last;
      lastChild.isGroupEnd = true;
    }
  }

  Future<void> visitCssStylesheet(CssStylesheet node) async {
    for (var statement in node.children) {
      await statement.accept(this);
    }
  }

  Future<void> visitCssSupportsRule(CssSupportsRule node) async {
    // NOTE: this logic is largely duplicated in [visitSupportsRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Supports rules may not be used within nested declarations.",
          node.span);
    }

    await _withParent(ModifiableCssSupportsRule(node.condition, node.span),
        () async {
      var styleRule = _styleRule;
      if (styleRule == null) {
        for (var child in node.children) {
          await child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the supports rule so that
        // declarations immediately inside @supports have somewhere to go.
        //
        // For example, "a {@supports (a: b) {b: c}}" should produce "@supports
        // (a: b) {a {b: c}}".
        await _withParent(styleRule.copyWithoutChildren(), () async {
          for (var child in node.children) {
            await child.accept(this);
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
  Future<Value?> _handleReturn<T>(
      List<T> list, Future<Value?> callback(T value)) async {
    for (var value in list) {
      var result = await callback(value);
      if (result != null) return result;
    }
    return null;
  }

  /// Runs [callback] with [environment] as the current environment.
  Future<T> _withEnvironment<T>(
      AsyncEnvironment environment, Future<T> callback()) async {
    var oldEnvironment = _environment;
    _environment = environment;
    var result = await callback();
    _environment = oldEnvironment;
    return result;
  }

  /// Evaluates [interpolation] and wraps the result in a [CssValue].
  ///
  /// If [trim] is `true`, removes whitespace around the result. If
  /// [warnForColor] is `true`, this will emit a warning for any named color
  /// values passed into the interpolation.
  Future<CssValue<String>> _interpolationToValue(Interpolation interpolation,
      {bool trim = false, bool warnForColor = false}) async {
    var result =
        await _performInterpolation(interpolation, warnForColor: warnForColor);
    return CssValue(trim ? trimAscii(result, excludeEscape: true) : result,
        interpolation.span);
  }

  /// Evaluates [interpolation].
  ///
  /// If [warnForColor] is `true`, this will emit a warning for any named color
  /// values passed into the interpolation.
  Future<String> _performInterpolation(Interpolation interpolation,
      {bool warnForColor = false}) async {
    return (await mapAsync(interpolation.contents, (value) async {
      if (value is String) return value;
      var expression = value as Expression;
      var result = await expression.accept(this);

      if (warnForColor &&
          result is SassColor &&
          namesByColor.containsKey(result)) {
        var alternative = BinaryOperationExpression(
            BinaryOperator.plus,
            StringExpression(Interpolation([""], interpolation.span),
                quotes: true),
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
    }))
        .join();
  }

  /// Evaluates [expression] and calls `toCssString()` and wraps a
  /// [SassScriptException] to associate it with [span].
  Future<String> _evaluateToCss(Expression expression,
          {bool quote = true}) async =>
      _serialize(await expression.accept(this), expression, quote: quote);

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
  /// This returns an [AstNode] rather than a [FileSpan] so we can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  AstNode _expressionNode(AstNode expression) {
    // TODO(nweiz): This used to return [expression] as-is if source map
    // generation was disabled. We always have to track the original location
    // now to produce better warnings for /-as-division, but once those warnings
    // are gone we should go back to short-circuiting.

    if (expression is VariableExpression) {
      return _addExceptionSpan(
              expression,
              () => _environment.getVariableNode(expression.name,
                  namespace: expression.namespace)) ??
          expression;
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
  Future<T> _withParent<S extends ModifiableCssParentNode, T>(
      S node, Future<T> callback(),
      {bool through(CssNode node)?, bool scopeWhen = true}) async {
    _addChild(node, through: through);

    var oldParent = _parent;
    _parent = node;
    var result = await _environment.scope(callback, when: scopeWhen);
    _parent = oldParent;

    return result;
  }

  /// Adds [node] as a child of the current parent.
  ///
  /// If [through] is passed, [node] is added as a child of the first parent for
  /// which [through] returns `false` instead. That parent is copied unless it's the
  /// lattermost child of its parent.
  void _addChild(ModifiableCssNode node, {bool through(CssNode node)?}) {
    // Go up through parents that match [through].
    var parent = _parent;
    if (through != null) {
      while (through(parent)) {
        var grandparent = parent.parent;
        if (grandparent == null) {
          throw ArgumentError(
              "through() must return false for at least one parent of $node.");
        }
        parent = grandparent;
      }

      // If the parent has a (visible) following sibling, we shouldn't add to
      // the parent. Instead, we should create a copy and add it after the
      // interstitial sibling.
      if (parent.hasFollowingSibling) {
        // A node with siblings must have a parent
        var grandparent = parent.parent!;
        parent = parent.copyWithoutChildren();
        grandparent.addChild(parent);
      }
    }

    parent.addChild(node);
  }

  /// Runs [callback] with [rule] as the current style rule.
  Future<T> _withStyleRule<T>(
      ModifiableCssStyleRule rule, Future<T> callback()) async {
    var oldRule = _styleRuleIgnoringAtRoot;
    _styleRuleIgnoringAtRoot = rule;
    var result = await callback();
    _styleRuleIgnoringAtRoot = oldRule;
    return result;
  }

  /// Runs [callback] with [queries] as the current media queries.
  Future<T> _withMediaQueries<T>(
      List<CssMediaQuery>? queries, Future<T> callback()) async {
    var oldMediaQueries = _mediaQueries;
    _mediaQueries = queries;
    var result = await callback();
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
  Future<T> _withStackFrame<T>(
      String member, AstNode nodeWithSpan, Future<T> callback()) async {
    _stack.add(Tuple2(_member, nodeWithSpan));
    var oldMember = _member;
    _member = member;
    var result = await callback();
    _member = oldMember;
    _stack.removeLast();
    return result;
  }

  /// Like [Value.withoutSlash], but produces a deprecation warning if [value]
  /// was a slash-separated number.
  Value _withoutSlash(Value value, AstNode nodeForSpan) {
    if (value is SassNumber && value.asSlash != null) {
      String recommendation(SassNumber number) {
        var asSlash = number.asSlash;
        if (asSlash != null) {
          return "math.div(${recommendation(asSlash.item1)}, "
              "${recommendation(asSlash.item2)})";
        } else {
          return number.toString();
        }
      }

      _warn(
          "Using / for division is deprecated and will be removed in Dart Sass "
          "2.0.0.\n"
          "\n"
          "Recommendation: ${recommendation(value)}\n"
          "\n"
          "More info and automated migrator: "
          "https://sass-lang.com/d/slash-div",
          nodeForSpan.span,
          deprecation: true);
    }

    return value.withoutSlash();
  }

  /// Creates a new stack frame with location information from [member] and
  /// [span].
  Frame _stackFrame(String member, FileSpan span) => frameForSpan(span, member,
      url: span.sourceUrl.andThen((url) => _importCache?.humanize(url) ?? url));

  /// Returns a stack trace at the current point.
  ///
  /// If [span] is passed, it's used for the innermost stack frame.
  Trace _stackTrace([FileSpan? span]) {
    var frames = [
      ..._stack.map((tuple) => _stackFrame(tuple.item1, tuple.item2.span)),
      if (span != null) _stackFrame(_member, span)
    ];
    return Trace(frames.reversed);
  }

  /// Emits a warning with the given [message] about the given [span].
  void _warn(String message, FileSpan span, {bool deprecation = false}) {
    if (_quietDeps && _inDependency) return;
    if (!_warningsEmitted.add(Tuple2(message, span))) return;
    _logger.warn(message,
        span: span, trace: _stackTrace(span), deprecation: deprecation);
  }

  /// Returns a [SassRuntimeException] with the given [message].
  ///
  /// If [span] is passed, it's used for the innermost stack frame.
  SassRuntimeException _exception(String message, [FileSpan? span]) =>
      SassRuntimeException(
          message, span ?? _stack.last.item2.span, _stackTrace(span));

  /// Returns a [MultiSpanSassRuntimeException] with the given [message],
  /// [primaryLabel], and [secondaryLabels].
  ///
  /// The primary span is taken from the current stack trace span.
  SassRuntimeException _multiSpanException(String message, String primaryLabel,
          Map<FileSpan, String> secondaryLabels) =>
      MultiSpanSassRuntimeException(message, _stack.last.item2.span,
          primaryLabel, secondaryLabels, _stackTrace());

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
    } on MultiSpanSassScriptException catch (error) {
      throw MultiSpanSassRuntimeException(
          error.message,
          nodeWithSpan.span,
          error.primaryLabel,
          error.secondarySpans,
          _stackTrace(nodeWithSpan.span));
    } on SassScriptException catch (error) {
      throw _exception(error.message, nodeWithSpan.span);
    }
  }

  /// Like [_addExceptionSpan], but for an asynchronous [callback].
  Future<T> _addExceptionSpanAsync<T>(
      AstNode nodeWithSpan, FutureOr<T> callback()) async {
    try {
      return await callback();
    } on MultiSpanSassScriptException catch (error) {
      throw MultiSpanSassRuntimeException(
          error.message,
          nodeWithSpan.span,
          error.primaryLabel,
          error.secondarySpans,
          _stackTrace(nodeWithSpan.span));
    } on SassScriptException catch (error) {
      throw _exception(error.message, nodeWithSpan.span);
    }
  }

  /// Runs [callback], and converts any [SassRuntimeException]s containing an
  /// @error to throw a more relevant [SassRuntimeException] with [nodeWithSpan]'s
  /// source span.
  Future<T> _addErrorSpan<T>(AstNode nodeWithSpan, Future<T> callback()) async {
    try {
      return await callback();
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
      (_visitor._outOfOrderImports ??= []).add(node);
    }
  }

  void visitCssKeyframeBlock(ModifiableCssKeyframeBlock node) {
    assert(false, "visitCssKeyframeBlock() should never be called.");
  }

  void visitCssMediaRule(ModifiableCssMediaRule node) {
    // Whether [node.query] has been merged with [_visitor._mediaQueries]. If it
    // has been merged, merging again is a no-op; if it hasn't been merged,
    // merging again will fail.
    var mediaQueries = _visitor._mediaQueries;
    var hasBeenMerged = mediaQueries == null ||
        _visitor._mergeMediaQueries(mediaQueries, node.queries) != null;

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

/// The result of compiling a Sass document to a CSS tree, along with metadata
/// about the compilation process.
class EvaluateResult {
  /// The CSS syntax tree.
  final CssStylesheet stylesheet;

  /// The canonical URLs of all stylesheets loaded during compilation.
  final Set<Uri> loadedUrls;

  EvaluateResult(this.stylesheet, this.loadedUrls);
}

/// The result of evaluating arguments to a function or mixin.
class _ArgumentResults {
  /// Arguments passed by position.
  final List<Value> positional;

  /// The [AstNode]s that hold the spans for each [positional] argument.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final List<AstNode> positionalNodes;

  /// Arguments passed by name.
  final Map<String, Value> named;

  /// The [AstNode]s that hold the spans for each [named] argument.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final Map<String, AstNode> namedNodes;

  /// The separator used for the rest argument list, if any.
  final ListSeparator separator;

  _ArgumentResults(this.positional, this.positionalNodes, this.named,
      this.namedNodes, this.separator);
}

/// The result of loading a stylesheet via [AsyncEvaluator._loadStylesheet].
class _LoadedStylesheet {
  /// The stylesheet itself.
  final Stylesheet stylesheet;

  /// The importer that was used to load the stylesheet.
  ///
  /// This is `null` when running in Node Sass compatibility mode.
  final AsyncImporter? importer;

  /// Whether this load counts as a dependency.
  ///
  /// That is, whether this was (transitively) loaded through a load path or
  /// importer rather than relative to the entrypoint.
  final bool isDependency;

  _LoadedStylesheet(this.stylesheet,
      {this.importer, required this.isDependency});
}
