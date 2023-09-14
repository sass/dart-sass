// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_evaluate.dart.
// See tool/grind/synchronize.dart for details.
//
// Checksum: ccd4ec1a65cfc2487fccd30481d427086f5c76cc
//
// ignore_for_file: unused_import

import 'async_evaluate.dart' show EvaluateResult;
export 'async_evaluate.dart' show EvaluateResult;

import 'dart:collection';
import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

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
import '../deprecation.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../extend/extension_store.dart';
import '../extend/extension.dart';
import '../functions.dart';
import '../functions/meta.dart' as meta;
import '../importer.dart';
import '../importer/legacy_node.dart';
import '../interpolation_map.dart';
import '../io.dart';
import '../logger.dart';
import '../module.dart';
import '../module/built_in.dart';
import '../parse/keyframe_selector.dart';
import '../syntax.dart';
import '../utils.dart';
import '../util/character.dart';
import '../util/map.dart';
import '../util/multi_span.dart';
import '../util/nullable.dart';
import '../util/span.dart';
import '../value.dart';
import 'expression_to_calc.dart';
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
        {ImportCache? importCache,
        NodeImporter? nodeImporter,
        Importer? importer,
        Iterable<Callable>? functions,
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
final class Evaluator {
  /// The visitor that evaluates each expression and statement.
  final _EvaluateVisitor _visitor;

  /// The importer to use to resolve `@use` rules in [_visitor].
  final Importer? _importer;

  /// Creates an evaluator.
  ///
  /// Arguments are the same as for [evaluate].
  Evaluator(
      {ImportCache? importCache,
      Importer? importer,
      Iterable<Callable>? functions,
      Logger? logger})
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
final class _EvaluateVisitor
    implements
        StatementVisitor<Value?>,
        ExpressionVisitor<Value>,
        CssVisitor<void> {
  /// The import cache used to import other stylesheets.
  final ImportCache? _importCache;

  /// The Node Sass-compatible importer to use when loading new Sass files when
  /// compiled to Node.js.
  final NodeImporter? _nodeImporter;

  /// Built-in functions that are globally-accessible, even under the new module
  /// system.
  final _builtInFunctions = <String, Callable>{};

  /// Built in modules, indexed by their URLs.
  final _builtInModules = <Uri, Module<Callable>>{};

  /// All modules that have been loaded and evaluated so far.
  final _modules = <Uri, Module<Callable>>{};

  /// The first [Configuration] used to load a module [Uri].
  final _moduleConfigurations = <Uri, Configuration>{};

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
  final _warningsEmitted = <(String, SourceSpan)>{};

  /// Whether to avoid emitting warnings for files loaded from dependencies.
  final bool _quietDeps;

  /// Whether to track source map information.
  final bool _sourceMap;

  /// The current lexical environment.
  Environment _environment;

  /// The style rule that defines the current parent selector, if any.
  ///
  /// This doesn't take into consideration any intermediate `@at-root` rules. In
  /// the common case where those rules are relevant, use [_styleRule] instead.
  ModifiableCssStyleRule? _styleRuleIgnoringAtRoot;

  /// The current media queries, if any.
  List<CssMediaQuery>? _mediaQueries;

  /// The set of media queries that were merged together to create
  /// [_mediaQueries].
  ///
  /// This will be non-null if and only if [_mediaQueries] is non-null, but it
  /// will be empty if [_mediaQueries] isn't the result of a merge.
  Set<CssMediaQuery>? _mediaQuerySources;

  /// The current parent node in the output CSS tree.
  ModifiableCssParentNode get _parent => _assertInModule(__parent, "__parent");
  set _parent(ModifiableCssParentNode value) => __parent = value;

  ModifiableCssParentNode? __parent;

  /// The name of the current declaration parent.
  String? _declarationName;

  /// The human-readable name of the current stack frame.
  var _member = "root stylesheet";

  /// The innermost user-defined callable that's being invoked.
  UserDefinedCallable<Environment>? _currentCallable;

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

  /// Whether we're currently evaluating a [SupportsDeclaration].
  ///
  /// When this is true, calculations will not be simplified.
  var _inSupportsDeclaration = false;

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
  /// Each member is a pair of the span where the stack trace starts and the
  /// name of the member being invoked.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final _stack = <(String, AstNode)>[];

  /// Whether we're running in Node Sass-compatibility mode.
  bool get _asNodeSass => _nodeImporter != null;

  // ## Module-Specific Fields

  /// The importer that's currently being used to resolve relative imports.
  ///
  /// If this is `null`, relative imports aren't supported in the current
  /// stylesheet.
  Importer? _importer;

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

  /// A map from modules loaded by the current module to loud comments written
  /// in this module that should appear before the loaded module.
  ///
  /// This is `null` unless there are any pre-module comments in the current
  /// stylesheet.
  Map<Module<Callable>, List<CssComment>>? _preModuleComments;

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
  /// Most arguments are the same as those to [evaluate].
  _EvaluateVisitor(
      {ImportCache? importCache,
      NodeImporter? nodeImporter,
      Iterable<Callable>? functions,
      Logger? logger,
      bool quietDeps = false,
      bool sourceMap = false})
      : _importCache = nodeImporter == null
            ? importCache ?? ImportCache.none(logger: logger)
            : null,
        _nodeImporter = nodeImporter,
        _logger = logger ?? const Logger.stderr(),
        _quietDeps = quietDeps,
        _sourceMap = sourceMap,
        // The default environment is overridden in [_execute] for full
        // stylesheets, but for [AsyncEvaluator] this environment is used.
        _environment = Environment() {
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
          for (var (name, value) in module.variables.pairs)
            SassString(name): value
        });
      }, url: "sass:meta"),

      BuiltInCallable.function("module-functions", r"$module", (arguments) {
        var namespace = arguments[0].assertString("module");
        var module = _environment.modules[namespace.text];
        if (module == null) {
          throw 'There is no module with namespace "${namespace.text}".';
        }

        return SassMap({
          for (var (name, value) in module.functions.pairs)
            SassString(name): SassFunction(value)
        });
      }, url: "sass:meta"),

      BuiltInCallable.function(
          "get-function", r"$name, $css: false, $module: null", (arguments) {
        var name = arguments[0].assertString("name");
        var css = arguments[1].isTruthy;
        var module = arguments[2].realNull?.assertString("module");

        if (css) {
          if (module != null) {
            throw r"$css and $module may not both be passed at once.";
          }
          return SassFunction(PlainCssCallable(name.text));
        }

        var callable = _addExceptionSpan(_callableNode!, () {
          var normalizedName = name.text.replaceAll("_", "-");
          var namespace = module?.text;
          var local =
              _environment.getFunction(normalizedName, namespace: namespace);
          if (local != null || namespace != null) return local;
          return _builtInFunctions[normalizedName];
        });
        if (callable == null) throw "Function not found: $name";

        return SassFunction(callable);
      }, url: "sass:meta"),

      BuiltInCallable.function("call", r"$function, $args...", (arguments) {
        var function = arguments[0];
        var args = arguments[1] as SassArgumentList;

        var callableNode = _callableNode!;
        var invocation = ArgumentInvocation([], {}, callableNode.span,
            rest: ValueExpression(args, callableNode.span),
            keywordRest: args.keywords.isEmpty
                ? null
                : ValueExpression(
                    SassMap({
                      for (var (name, value) in args.keywords.pairs)
                        SassString(name, quotes: false): value
                    }),
                    callableNode.span));

        if (function is SassString) {
          warnForDeprecation(
              "Passing a string to call() is deprecated and will be illegal in "
              "Dart Sass 2.0.0.\n"
              "\n"
              "Recommendation: call(get-function($function))",
              Deprecation.callString);

          var callableNode = _callableNode!;
          var expression =
              FunctionExpression(function.text, invocation, callableNode.span);
          return expression.accept(this);
        }

        var callable = function.assertFunction("function").callable;
        // ignore: unnecessary_type_check
        if (callable is Callable) {
          return _runFunctionCallable(invocation, callable, _callableNode!);
        } else {
          throw SassScriptException(
              "The function ${callable.name} is asynchronous.\n"
              "This is probably caused by a bug in a Sass plugin.");
        }
      }, url: "sass:meta")
    ];

    var metaMixins = [
      BuiltInCallable.mixin("load-css", r"$url, $with: null", (arguments) {
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

        _loadModule(url, "load-css()", callableNode,
            (module, _) => _combineCss(module, clone: true).accept(this),
            baseUrl: callableNode.span.sourceUrl,
            configuration: configuration,
            namesInErrors: true);
        _assertConfigurationIsEmpty(configuration, nameInError: true);
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

  EvaluateResult run(Importer? importer, Stylesheet node) {
    try {
      return withEvaluationContext(_EvaluationContext(this, node), () {
        if (node.span.sourceUrl case var url?) {
          _activeModules[url] = null;
          if (!(_asNodeSass && url.toString() == 'stdin')) _loadedUrls.add(url);
        }

        var module = _addExceptionTrace(() => _execute(importer, node));
        return (stylesheet: _combineCss(module), loadedUrls: _loadedUrls);
      });
    } on SassException catch (error, stackTrace) {
      throwWithTrace(error.withLoadedUrls(_loadedUrls), error, stackTrace);
    }
  }

  Value runExpression(Importer? importer, Expression expression) =>
      withEvaluationContext(
          _EvaluationContext(this, expression),
          () => _withFakeStylesheet(importer, expression,
              () => _addExceptionTrace(() => expression.accept(this))));

  void runStatement(Importer? importer, Statement statement) =>
      withEvaluationContext(
          _EvaluationContext(this, statement),
          () => _withFakeStylesheet(importer, statement,
              () => _addExceptionTrace(() => statement.accept(this))));

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
  T _withFakeStylesheet<T>(
      Importer? importer, AstNode nodeWithSpan, T callback()) {
    var oldImporter = _importer;
    _importer = importer;

    assert(__stylesheet == null);
    _stylesheet = Stylesheet(const [], nodeWithSpan.span);

    try {
      return callback();
    } finally {
      _importer = oldImporter;
      __stylesheet = null;
    }
  }

  /// Loads the module at [url] and passes it to [callback], along with a
  /// boolean indicating whether this is the first time the module has been
  /// loaded.
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
  void _loadModule(Uri url, String stackFrame, AstNode nodeWithSpan,
      void callback(Module<Callable> module, bool firstLoad),
      {Uri? baseUrl,
      Configuration? configuration,
      bool namesInErrors = false}) {
    if (_builtInModules[url] case var builtInModule?) {
      if (configuration is ExplicitConfiguration) {
        throw _exception(
            namesInErrors
                ? "Built-in module $url can't be configured."
                : "Built-in modules can't be configured.",
            configuration.nodeWithSpan.span);
      }

      // Always consider built-in stylesheets to be "already loaded", since they
      // never require additional execution to load and never produce CSS.
      _addExceptionSpan(nodeWithSpan, () => callback(builtInModule, false));
      return;
    }

    _withStackFrame(stackFrame, nodeWithSpan, () {
      var (stylesheet, :importer, :isDependency) =
          _loadStylesheet(url.toString(), nodeWithSpan.span, baseUrl: baseUrl);

      var canonicalUrl = stylesheet.span.sourceUrl;
      if (canonicalUrl != null) {
        if (_activeModules.containsKey(canonicalUrl)) {
          var message = namesInErrors
              ? "Module loop: ${p.prettyUri(canonicalUrl)} is already being "
                  "loaded."
              : "Module loop: this module is already being loaded.";

          throw _activeModules[canonicalUrl].andThen((previousLoad) =>
                  _multiSpanException(message, "new load",
                      {previousLoad.span: "original load"})) ??
              _exception(message);
        } else {
          _activeModules[canonicalUrl] = nodeWithSpan;
        }
      }

      var firstLoad = !_modules.containsKey(canonicalUrl);
      var oldInDependency = _inDependency;
      _inDependency = isDependency;
      Module<Callable> module;
      try {
        module = _execute(importer, stylesheet,
            configuration: configuration,
            nodeWithSpan: nodeWithSpan,
            namesInErrors: namesInErrors);
      } finally {
        _activeModules.remove(canonicalUrl);
        _inDependency = oldInDependency;
      }

      _addExceptionSpan(nodeWithSpan, () => callback(module, firstLoad),
          addStackFrame: false);
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
  Module<Callable> _execute(Importer? importer, Stylesheet stylesheet,
      {Configuration? configuration,
      AstNode? nodeWithSpan,
      bool namesInErrors = false}) {
    var url = stylesheet.span.sourceUrl;

    if (_modules[url] case var alreadyLoaded?) {
      var currentConfiguration = configuration ?? _configuration;
      if (!_moduleConfigurations[url]!.sameOriginal(currentConfiguration) &&
          currentConfiguration is ExplicitConfiguration) {
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

    var environment = Environment();
    late CssStylesheet css;
    late Map<Module<Callable>, List<CssComment>>? preModuleComments;
    var extensionStore = ExtensionStore();
    _withEnvironment(environment, () {
      var oldImporter = _importer;
      var oldStylesheet = __stylesheet;
      var oldRoot = __root;
      var oldPreModuleComments = _preModuleComments;
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

      visitStylesheet(stylesheet);
      css = _outOfOrderImports == null
          ? root
          : CssStylesheet(_addOutOfOrderImports(), stylesheet.span);
      preModuleComments = _preModuleComments;

      _importer = oldImporter;
      __stylesheet = oldStylesheet;
      __root = oldRoot;
      _preModuleComments = oldPreModuleComments;
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

    var module = environment.toModule(
        css, preModuleComments ?? const {}, extensionStore);
    if (url != null) {
      _modules[url] = module;
      _moduleConfigurations[url] = _configuration;
      if (nodeWithSpan != null) _moduleNodes[url] = nodeWithSpan;
    }

    return module;
  }

  /// Returns a copy of [_root.children] with [_outOfOrderImports] inserted
  /// after [_endOfImports], if necessary.
  List<ModifiableCssNode> _addOutOfOrderImports() =>
      switch (_outOfOrderImports) {
        null => _root.children,
        var outOfOrderImports => [
            ..._root.children.take(_endOfImports),
            ...outOfOrderImports,
            ..._root.children.skip(_endOfImports)
          ]
      };

  /// Returns a new stylesheet containing [root]'s CSS as well as the CSS of all
  /// modules transitively used by [root].
  ///
  /// This also applies each module's extensions to its upstream modules.
  ///
  /// If [clone] is `true`, this will copy the modules before extending them so
  /// that they don't modify [root] or its dependencies.
  CssStylesheet _combineCss(Module<Callable> root, {bool clone = false}) {
    if (!root.upstream.any((module) => module.transitivelyContainsCss)) {
      var selectors = root.extensionStore.simpleSelectors;
      if (root.extensionStore
              .extensionsWhereTarget((target) => !selectors.contains(target))
              .firstOrNull
          case var unsatisfiedExtension?) {
        _throwForUnsatisfiedExtension(unsatisfiedExtension);
      }

      return root.css;
    }

    // The imports (and comments between them) that should be included at the
    // beginning of the final document.
    var imports = <CssNode>[];

    // The CSS statements in the final document.
    var css = <CssNode>[];

    /// The modules in reverse topological order.
    var sorted = Queue<Module<Callable>>();

    /// The modules that have been visited so far. Note that if [cloneCss] is
    /// true, this contains the original modules, not the copies.
    var seen = <Module<Callable>>{};

    void visitModule(Module<Callable> module) {
      if (!seen.add(module)) return;
      if (clone) module = module.cloneCss();

      for (var upstream in module.upstream) {
        if (upstream.transitivelyContainsCss) {
          if (module.preModuleComments[upstream] case var comments?) {
            // Intermix the top-level comments with plain CSS `@import`s until we
            // start to have actual CSS defined, at which point start treating it as
            // normal CSS.
            (css.isEmpty ? imports : css).addAll(comments);
          }
          visitModule(upstream);
        }
      }

      sorted.addFirst(module);
      var statements = module.css.children;
      var index = _indexAfterImports(statements);
      imports.addAll(statements.getRange(0, index));
      css.addAll(statements.getRange(index, statements.length));
    }

    visitModule(root);

    if (root.transitivelyContainsExtensions) _extendModules(sorted);

    return CssStylesheet(imports + css, root.css.span);
  }

  /// Destructively updates the selectors in each module with the extensions
  /// defined in downstream modules.
  void _extendModules(Iterable<Module<Callable>> sortedModules) {
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
        if (upstream.url case var url?) {
          downstreamExtensionStores
              .putIfAbsent(url, () => [])
              .add(module.extensionStore);
        }
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

  /// Returns the index of the first node in [statements] that comes after all
  /// static imports.
  int _indexAfterImports(List<CssNode> statements) {
    var lastImport = -1;
    loop:
    for (var i = 0; i < statements.length; i++) {
      switch (statements[i]) {
        case CssImport():
          lastImport = i;
        case CssComment():
          continue loop;
        case _:
          break loop;
      }
    }
    return lastImport + 1;
  }

  // ## Statements

  Value? visitStylesheet(Stylesheet node) {
    for (var child in node.children) {
      child.accept(this);
    }
    return null;
  }

  Value? visitAtRootRule(AtRootRule node) {
    var query = AtRootQuery.defaultQuery;
    if (node.query case var unparsedQuery?) {
      var (resolved, map) =
          _performInterpolationWithMap(unparsedQuery, warnForColor: true);
      query =
          AtRootQuery.parse(resolved, interpolationMap: map, logger: _logger);
    }

    var parent = _parent;
    var included = <ModifiableCssParentNode>[];
    while (parent is! CssStylesheet) {
      if (!query.excludes(parent)) included.add(parent);

      if (parent.parent case var grandparent?) {
        parent = grandparent;
      } else {
        throw StateError(
            "CssNodes must have a CssStylesheet transitive parent node.");
      }
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

    var innerCopy = root;
    if (included case [var first, ...var rest]) {
      innerCopy = first.copyWithoutChildren();
      var outerCopy = innerCopy;
      for (var node in rest) {
        var copy = node.copyWithoutChildren();
        copy.addChild(outerCopy);
        outerCopy = copy;
      }

      root.addChild(outerCopy);
    }

    _scopeForAtRoot(node, innerCopy, query, included)(() {
      for (var child in node.children) {
        child.accept(this);
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

        if (parent.parent case var grandparent?) {
          parent = grandparent;
        } else {
          throw ArgumentError(
              "Expected ${nodes[i]} to be an ancestor of $this.");
        }
      }
      innermostContiguous ??= i;

      if (parent.parent case var grandparent?) {
        parent = grandparent;
      } else {
        throw ArgumentError("Expected ${nodes[i]} to be an ancestor of $this.");
      }
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

    if (_mediaQueries != null && query.excludesName('media')) {
      var innerScope = scope;
      scope = (callback) =>
          _withMediaQueries(null, null, () => innerScope(callback));
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

  Value? visitContentRule(ContentRule node) {
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

  Value? visitDebugRule(DebugRule node) {
    var value = node.expression.accept(this);
    _logger.debug(
        value is SassString ? value.text : value.toString(), node.span);
    return null;
  }

  Value? visitDeclaration(Declaration node) {
    if (_styleRule == null && !_inUnknownAtRule && !_inKeyframes) {
      throw _exception(
          "Declarations may only be used within style rules.", node.span);
    }
    if (_declarationName != null && node.isCustomProperty) {
      throw _exception(
          'Declarations whose names begin with "--" may not be nested.',
          node.span);
    }

    var name = _interpolationToValue(node.name, warnForColor: true);
    if (_declarationName case var declarationName?) {
      name = CssValue("$declarationName-${name.value}", name.span);
    }

    if (node.value case var expression?) {
      var value = expression.accept(this);
      // If the value is an empty list, preserve it, because converting it to CSS
      // will throw an error that we want the user to see.
      if (!value.isBlank || _isEmptyList(value)) {
        _parent.addChild(ModifiableCssDeclaration(
            name, CssValue(value, expression.span), node.span,
            parsedAsCustomProperty: node.isCustomProperty,
            valueSpanForMap:
                _sourceMap ? node.value.andThen(_expressionNode)?.span : null));
      } else if (name.value.startsWith('--')) {
        throw _exception(
            "Custom property values may not be empty.", expression.span);
      }
    }

    if (node.children case var children?) {
      var oldDeclarationName = _declarationName;
      _declarationName = name.value;
      _environment.scope(() {
        for (var child in children) {
          child.accept(this);
        }
      }, when: node.hasDeclarations);
      _declarationName = oldDeclarationName;
    }

    return null;
  }

  /// Returns whether [value] is an empty list.
  bool _isEmptyList(Value value) => value.asList.isEmpty;

  Value? visitEachRule(EachRule node) {
    var list = node.list.accept(this);
    var nodeWithSpan = _expressionNode(node.list);
    var setVariables = switch (node.variables) {
      [var variable] => (Value value) => _environment.setLocalVariable(
          variable, _withoutSlash(value, nodeWithSpan), nodeWithSpan),
      var variables => (Value value) =>
          _setMultipleVariables(variables, value, nodeWithSpan)
    };
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

  Value visitErrorRule(ErrorRule node) {
    throw _exception(node.expression.accept(this).toString(), node.span);
  }

  Value? visitExtendRule(ExtendRule node) {
    var styleRule = _styleRule;
    if (styleRule == null || _declarationName != null) {
      throw _exception(
          "@extend may only be used within style rules.", node.span);
    }

    for (var complex in styleRule.originalSelector.components) {
      if (!complex.isBogus) continue;
      _warn(
          'The selector "${complex.toString().trim()}" is invalid CSS and ' +
              (complex.isUseless ? "can't" : "shouldn't") +
              ' be an extender.\n'
                  'This will be an error in Dart Sass 2.0.0.\n'
                  '\n'
                  'More info: https://sass-lang.com/d/bogus-combinators',
          MultiSpan(complex.span.trimRight(), 'invalid selector',
              {node.span: '@extend rule'}),
          Deprecation.bogusCombinators);
    }

    var (targetText, targetMap) =
        _performInterpolationWithMap(node.selector, warnForColor: true);

    var list = SelectorList.parse(trimAscii(targetText, excludeEscape: true),
        interpolationMap: targetMap, logger: _logger, allowParent: false);

    for (var complex in list.components) {
      var compound = complex.singleCompound;
      if (compound == null) {
        // If the selector was a compound selector but not a simple
        // selector, emit a more explicit error.
        throw SassFormatException(
            "complex selectors may not be extended.", complex.span);
      }

      var simple = compound.singleSimple;
      if (simple == null) {
        throw SassFormatException(
            "compound selectors may no longer be extended.\n"
            "Consider `@extend ${compound.components.join(', ')}` instead.\n"
            "See https://sass-lang.com/d/extend-compound for details.\n",
            compound.span);
      }

      _extensionStore.addExtension(
          styleRule.selector, simple, node, _mediaQueries);
    }

    return null;
  }

  Value? visitAtRule(AtRule node) {
    // NOTE: this logic is largely duplicated in [visitCssAtRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "At-rules may not be used within nested declarations.", node.span);
    }

    var name = _interpolationToValue(node.name);

    var value = node.value.andThen((value) =>
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

    _withParent(ModifiableCssAtRule(name, node.span, value: value), () {
      var styleRule = _styleRule;
      if (styleRule == null || _inKeyframes || name.value == 'font-face') {
        // Special-cased at-rules within style blocks are pulled out to the
        // root. Equivalent to prepending "@at-root" on them.
        for (var child in children) {
          child.accept(this);
        }
      } else {
        // If we're in a style rule, copy it into the at-rule so that
        // declarations immediately inside it have somewhere to go.
        //
        // For example, "a {@foo {b: c}}" should produce "@foo {a {b: c}}".
        _withParent(styleRule.copyWithoutChildren(), () {
          for (var child in children) {
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

  Value? visitForRule(ForRule node) {
    var fromNumber = _addExceptionSpan(
        node.from, () => node.from.accept(this).assertNumber());
    var toNumber =
        _addExceptionSpan(node.to, () => node.to.accept(this).assertNumber());

    var from = _addExceptionSpan(node.from, () => fromNumber.assertInt());
    var to = _addExceptionSpan(
        node.to,
        () => toNumber
            .coerce(fromNumber.numeratorUnits, fromNumber.denominatorUnits)
            .assertInt());

    var direction = from > to ? -1 : 1;
    if (!node.isExclusive) to += direction;
    if (from == to) return null;

    return _environment.scope(() {
      var nodeWithSpan = _expressionNode(node.from);
      for (var i = from; i != to; i += direction) {
        _environment.setLocalVariable(
            node.variable,
            SassNumber.withUnits(i,
                numeratorUnits: fromNumber.numeratorUnits,
                denominatorUnits: fromNumber.denominatorUnits),
            nodeWithSpan);
        if (_handleReturn<Statement>(
                node.children, (child) => child.accept(this))
            case var result?) {
          return result;
        }
      }
      return null;
    }, semiGlobal: true);
  }

  Value? visitForwardRule(ForwardRule node) {
    var oldConfiguration = _configuration;
    var adjustedConfiguration = oldConfiguration.throughForward(node);

    if (node.configuration.isNotEmpty) {
      var newConfiguration =
          _addForwardConfiguration(adjustedConfiguration, node);

      _loadModule(node.url, "@forward", node, (module, firstLoad) {
        if (firstLoad) _registerCommentsForModule(module);
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
      _loadModule(node.url, "@forward", node, (module, firstLoad) {
        if (firstLoad) _registerCommentsForModule(module);
        _environment.forwardModule(module, node);
      });
      _configuration = oldConfiguration;
    }

    return null;
  }

  /// Updates [configuration] to include [node]'s configuration and returns the
  /// result.
  Configuration _addForwardConfiguration(
      Configuration configuration, ForwardRule node) {
    var newValues = Map.of(configuration.values);
    for (var variable in node.configuration) {
      if (variable.isGuarded) {
        if (configuration.remove(variable.name) case var oldValue?
            when oldValue.value != sassNull) {
          newValues[variable.name] = oldValue;
          continue;
        }
      }

      var variableNodeWithSpan = _expressionNode(variable.expression);
      newValues[variable.name] = ConfiguredValue.explicit(
          _withoutSlash(variable.expression.accept(this), variableNodeWithSpan),
          variable.span,
          variableNodeWithSpan);
    }

    if (configuration is ExplicitConfiguration || configuration.isEmpty) {
      return ExplicitConfiguration(newValues, node);
    } else {
      return Configuration.implicit(newValues);
    }
  }

  /// Adds any comments in [_root.children] to [_preModuleComments] for
  /// [module].
  void _registerCommentsForModule(Module<Callable> module) {
    // If we're not in a module (for example, we're evaluating a line of code
    // for the repl), there's nothing to register comments for.
    if (__root == null) return;
    if (_root.children.isEmpty || !module.transitivelyContainsCss) return;
    (_preModuleComments ??= {})
        .putIfAbsent(module, () => [])
        .addAll(_root.children.cast<CssComment>());
    _root.clearChildren();
    _endOfImports = 0;
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

    var (name, value) = configuration.values.pairs.first;
    throw _exception(
        nameInError
            ? "\$$name was not declared with !default in the @used "
                "module."
            : "This variable was not declared with !default in the @used "
                "module.",
        value.configurationSpan);
  }

  Value? visitFunctionRule(FunctionRule node) {
    _environment.setFunction(UserDefinedCallable(node, _environment.closure(),
        inDependency: _inDependency));
    return null;
  }

  Value? visitIfRule(IfRule node) {
    IfRuleClause? clause = node.lastClause;
    for (var clauseToCheck in node.clauses) {
      if (clauseToCheck.expression.accept(this).isTruthy) {
        clause = clauseToCheck;
        break;
      }
    }

    return clause.andThen<Value?>((clause) => _environment.scope(
        () => _handleReturn<Statement>(
            clause.children, (child) => child.accept(this)),
        semiGlobal: true,
        when: clause.hasDeclarations));
  }

  Value? visitImportRule(ImportRule node) {
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
      var (stylesheet, :importer, :isDependency) =
          _loadStylesheet(import.urlString, import.span, forImport: true);

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
        _importer = importer;
        _stylesheet = stylesheet;
        _inDependency = isDependency;
        visitStylesheet(stylesheet);
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
      _withEnvironment(environment, () {
        var oldImporter = _importer;
        var oldStylesheet = _stylesheet;
        var oldRoot = _root;
        var oldParent = _parent;
        var oldEndOfImports = _endOfImports;
        var oldOutOfOrderImports = _outOfOrderImports;
        var oldConfiguration = _configuration;
        var oldInDependency = _inDependency;
        _importer = importer;
        _stylesheet = stylesheet;
        if (loadsUserDefinedModules) {
          _root = ModifiableCssStylesheet(stylesheet.span);
          _parent = _root;
          _endOfImports = 0;
          _outOfOrderImports = null;
        }
        _inDependency = isDependency;

        // This configuration is only used if it passes through a `@forward`
        // rule, so we avoid creating unnecessary ones for performance reasons.
        if (stylesheet.forwards.isNotEmpty) {
          _configuration = environment.toImplicitConfiguration();
        }

        visitStylesheet(stylesheet);
        children = loadsUserDefinedModules ? _addOutOfOrderImports() : [];

        _importer = oldImporter;
        _stylesheet = oldStylesheet;
        if (loadsUserDefinedModules) {
          _root = oldRoot;
          _parent = oldParent;
          _endOfImports = oldEndOfImports;
          _outOfOrderImports = oldOutOfOrderImports;
        }
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
          _combineCss(module, clone: module.transitivelyContainsExtensions)
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
  _LoadedStylesheet _loadStylesheet(String url, FileSpan span,
      {Uri? baseUrl, bool forImport = false}) {
    try {
      assert(_importSpan == null);
      _importSpan = span;

      if (_importCache case var importCache?) {
        baseUrl ??= _stylesheet.span.sourceUrl;
        if (importCache.canonicalize(Uri.parse(url),
                baseImporter: _importer, baseUrl: baseUrl, forImport: forImport)
            case (var importer, var canonicalUrl, :var originalUrl)) {
          // Make sure we record the canonical URL as "loaded" even if the
          // actual load fails, because watchers should watch it to see if it
          // changes in a way that allows the load to succeed.
          _loadedUrls.add(canonicalUrl);

          var isDependency = _inDependency || importer != _importer;
          if (importCache.importCanonical(importer, canonicalUrl,
                  originalUrl: originalUrl, quiet: _quietDeps && isDependency)
              case var stylesheet?) {
            return (stylesheet, importer: importer, isDependency: isDependency);
          }
        }
      } else {
        if (_importLikeNode(
                url, baseUrl ?? _stylesheet.span.sourceUrl, forImport)
            case var result?) {
          result.$1.span.sourceUrl.andThen(_loadedUrls.add);
          return result;
        }
      }

      if (url.startsWith('package:') && isJS) {
        // Special-case this error message, since it's tripped people up in the
        // past.
        throw "\"package:\" URLs aren't supported on this platform.";
      } else {
        throw "Can't find stylesheet to import.";
      }
    } on SassException {
      rethrow;
    } on ArgumentError catch (error, stackTrace) {
      throwWithTrace(_exception(error.toString()), error, stackTrace);
    } catch (error, stackTrace) {
      String? message;
      try {
        message = (error as dynamic).message as String;
      } catch (_) {
        message = error.toString();
      }
      throwWithTrace(_exception(message), error, stackTrace);
    } finally {
      _importSpan = null;
    }
  }

  /// Imports a stylesheet using [_nodeImporter].
  ///
  /// Returns the [Stylesheet], or `null` if the import failed.
  _LoadedStylesheet? _importLikeNode(
      String originalUrl, Uri? previous, bool forImport) {
    var result = _nodeImporter!.loadRelative(originalUrl, previous, forImport);

    bool isDependency;
    if (result != null) {
      isDependency = _inDependency;
    } else {
      result = _nodeImporter!.load(originalUrl, previous, forImport);
      if (result == null) return null;
      isDependency = true;
    }

    var (contents, url) = result;
    return (
      Stylesheet.parse(
          contents, url.startsWith('file') ? Syntax.forPath(url) : Syntax.scss,
          url: url,
          logger: _quietDeps && isDependency ? Logger.quiet : _logger),
      importer: null,
      isDependency: isDependency
    );
  }

  /// Adds a CSS import for [import].
  void _visitStaticImport(StaticImport import) {
    // NOTE: this logic is largely duplicated in [visitCssImport]. Most changes
    // here should be mirrored there.

    var node = ModifiableCssImport(
        _interpolationToValue(import.url), import.span,
        modifiers:
            import.modifiers.andThen<CssValue<String>?>(_interpolationToValue));

    if (_parent != _root) {
      _parent.addChild(node);
    } else if (_endOfImports == _root.children.length) {
      _root.addChild(node);
      _endOfImports++;
    } else {
      (_outOfOrderImports ??= []).add(node);
    }
  }

  Value? visitIncludeRule(IncludeRule node) {
    var nodeWithSpan = AstNode.fake(() => node.spanWithoutContent);
    var mixin = _addExceptionSpan(node,
        () => _environment.getMixin(node.name, namespace: node.namespace));
    switch (mixin) {
      case null:
        throw _exception("Undefined mixin.", node.span);

      case BuiltInCallable() when node.content != null:
        throw _exception("Mixin doesn't accept a content block.", node.span);

      case BuiltInCallable():
        _runBuiltInCallable(node.arguments, mixin, nodeWithSpan);

      case UserDefinedCallable<Environment>(
            declaration: MixinRule(hasContent: false)
          )
          when node.content != null:
        throw MultiSpanSassRuntimeException(
            "Mixin doesn't accept a content block.",
            node.spanWithoutContent,
            "invocation",
            {mixin.declaration.arguments.spanWithName: "declaration"},
            _stackTrace(node.spanWithoutContent));

      case UserDefinedCallable<Environment>():
        var contentCallable = node.content.andThen((content) =>
            UserDefinedCallable(content, _environment.closure(),
                inDependency: _inDependency));
        _runUserDefinedCallable(node.arguments, mixin, nodeWithSpan, () {
          _environment.withContent(contentCallable, () {
            _environment.asMixin(() {
              for (var statement in mixin.declaration.children) {
                _addErrorSpan(nodeWithSpan, () => statement.accept(this));
              }
            });
          });
        });

      case _:
        throw UnsupportedError("Unknown callable type $mixin.");
    }

    return null;
  }

  Value? visitMixinRule(MixinRule node) {
    _environment.setMixin(UserDefinedCallable(node, _environment.closure(),
        inDependency: _inDependency));
    return null;
  }

  Value? visitLoudComment(LoudComment node) {
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

  Value? visitMediaRule(MediaRule node) {
    // NOTE: this logic is largely duplicated in [visitCssMediaRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Media rules may not be used within nested declarations.", node.span);
    }

    var queries = _visitMediaQueries(node.query);
    var mergedQueries = _mediaQueries
        .andThen((mediaQueries) => _mergeMediaQueries(mediaQueries, queries));
    if (mergedQueries != null && mergedQueries.isEmpty) return null;

    var mergedSources = mergedQueries == null
        ? const <CssMediaQuery>{}
        : {..._mediaQuerySources!, ..._mediaQueries!, ...queries};

    _withParent(ModifiableCssMediaRule(mergedQueries ?? queries, node.span),
        () {
      _withMediaQueries(mergedQueries ?? queries, mergedSources, () {
        if (_styleRule case var styleRule?) {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          _withParent(styleRule.copyWithoutChildren(), () {
            for (var child in node.children) {
              child.accept(this);
            }
          }, scopeWhen: false);
        } else {
          for (var child in node.children) {
            child.accept(this);
          }
        }
      });
    },
        through: (node) =>
            node is CssStyleRule ||
            (mergedSources.isNotEmpty &&
                node is CssMediaRule &&
                node.queries.every(mergedSources.contains)),
        scopeWhen: node.hasDeclarations);

    return null;
  }

  /// Evaluates [interpolation] and parses the result as a list of media
  /// queries.
  List<CssMediaQuery> _visitMediaQueries(Interpolation interpolation) {
    var (resolved, map) =
        _performInterpolationWithMap(interpolation, warnForColor: true);
    return CssMediaQuery.parseList(resolved,
        logger: _logger, interpolationMap: map);
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
      inner:
      for (var query2 in queries2) {
        switch (query1.merge(query2)) {
          case MediaQueryMergeResult.empty:
            continue inner;
          case MediaQueryMergeResult.unrepresentable:
            return null;
          case MediaQuerySuccessfulMergeResult result:
            queries.add(result.query);
        }
      }
    }
    return queries;
  }

  Value visitReturnRule(ReturnRule node) =>
      _withoutSlash(node.expression.accept(this), node.expression);

  Value? visitSilentComment(SilentComment node) => null;

  Value? visitStyleRule(StyleRule node) {
    // NOTE: this logic is largely duplicated in [visitCssStyleRule]. Most
    // changes here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var (selectorText, selectorMap) =
        _performInterpolationWithMap(node.selector, warnForColor: true);

    if (_inKeyframes) {
      // NOTE: this logic is largely duplicated in [visitCssKeyframeBlock]. Most
      // changes here should be mirrored there.

      var parsedSelector = KeyframeSelectorParser(selectorText,
              logger: _logger, interpolationMap: selectorMap)
          .parse();
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

    var parsedSelector = SelectorList.parse(selectorText,
            interpolationMap: selectorMap,
            allowParent: !_stylesheet.plainCss,
            allowPlaceholder: !_stylesheet.plainCss,
            logger: _logger)
        .resolveParentSelectors(_styleRuleIgnoringAtRoot?.originalSelector,
            implicitParent: !_atRootExcludingStyleRule);

    var selector = _extensionStore.addSelector(parsedSelector, _mediaQueries);
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

    if (!rule.isInvisibleOtherThanBogusCombinators) {
      for (var complex in parsedSelector.components) {
        if (!complex.isBogus) continue;

        if (complex.isUseless) {
          _warn(
              'The selector "${complex.toString().trim()}" is invalid CSS. It '
              'will be omitted from the generated CSS.\n'
              'This will be an error in Dart Sass 2.0.0.\n'
              '\n'
              'More info: https://sass-lang.com/d/bogus-combinators',
              complex.span.trimRight(),
              Deprecation.bogusCombinators);
        } else if (complex.leadingCombinators.isNotEmpty) {
          _warn(
              'The selector "${complex.toString().trim()}" is invalid CSS.\n'
              'This will be an error in Dart Sass 2.0.0.\n'
              '\n'
              'More info: https://sass-lang.com/d/bogus-combinators',
              complex.span.trimRight(),
              Deprecation.bogusCombinators);
        } else {
          _warn(
              'The selector "${complex.toString().trim()}" is only valid for '
                      "nesting and shouldn't\n"
                      'have children other than style rules.' +
                  (complex.isBogusOtherThanLeadingCombinator
                      ? ' It will be omitted from the generated CSS.'
                      : '') +
                  '\n'
                      'This will be an error in Dart Sass 2.0.0.\n'
                      '\n'
                      'More info: https://sass-lang.com/d/bogus-combinators',
              MultiSpan(complex.span.trimRight(), 'invalid selector', {
                rule.children.first.span: "this is not a style rule" +
                    (rule.children.every((child) => child is CssComment)
                        ? '\n(try converting to a //-style comment)'
                        : '')
              }),
              Deprecation.bogusCombinators);
        }
      }
    }

    if (_styleRule == null && _parent.children.isNotEmpty) {
      var lastChild = _parent.children.last;
      lastChild.isGroupEnd = true;
    }

    return null;
  }

  Value? visitSupportsRule(SupportsRule node) {
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
      if (_styleRule case var styleRule?) {
        // If we're in a style rule, copy it into the supports rule so that
        // declarations immediately inside @supports have somewhere to go.
        //
        // For example, "a {@supports (a: b) {b: c}}" should produce "@supports
        // (a: b) {a {b: c}}".
        _withParent(styleRule.copyWithoutChildren(), () {
          for (var child in node.children) {
            child.accept(this);
          }
        });
      } else {
        for (var child in node.children) {
          child.accept(this);
        }
      }
    },
        through: (node) => node is CssStyleRule,
        scopeWhen: node.hasDeclarations);

    return null;
  }

  /// Evaluates [condition] and converts it to a plain CSS string.
  String _visitSupportsCondition(SupportsCondition condition) =>
      switch (condition) {
        SupportsOperation operation =>
          "${_parenthesize(operation.left, operation.operator)} "
              "${operation.operator} "
              "${_parenthesize(operation.right, operation.operator)}",
        SupportsNegation negation => "not ${_parenthesize(negation.condition)}",
        SupportsInterpolation interpolation =>
          _evaluateToCss(interpolation.expression, quote: false),
        SupportsDeclaration declaration =>
          _withSupportsDeclaration(() => "(${_evaluateToCss(declaration.name)}:"
              "${declaration.isCustomProperty ? '' : ' '}"
              "${_evaluateToCss(declaration.value)})"),
        SupportsFunction function => "${_performInterpolation(function.name)}("
            "${_performInterpolation(function.arguments)})",
        SupportsAnything anything =>
          "(${_performInterpolation(anything.contents)})",
        var condition => throw ArgumentError(
            "Unknown supports condition type ${condition.runtimeType}.")
      };

  /// Runs [callback] in a context where [_inSupportsDeclaration] is true.
  T _withSupportsDeclaration<T>(T callback()) {
    var oldInSupportsDeclaration = _inSupportsDeclaration;
    _inSupportsDeclaration = true;
    try {
      return callback();
    } finally {
      _inSupportsDeclaration = oldInSupportsDeclaration;
    }
  }

  /// Evaluates [condition] and converts it to a plain CSS string, with
  /// parentheses if necessary.
  ///
  /// If [operator] is passed, it's the operator for the surrounding
  /// [SupportsOperation], and is used to determine whether parentheses are
  /// necessary if [condition] is also a [SupportsOperation].
  String _parenthesize(SupportsCondition condition, [String? operator]) {
    switch (condition) {
      case SupportsNegation():
      case SupportsOperation()
          when operator == null || operator != condition.operator:
        return "(${_visitSupportsCondition(condition)})";

      case _:
        return _visitSupportsCondition(condition);
    }
  }

  Value? visitVariableDeclaration(VariableDeclaration node) {
    if (node.isGuarded) {
      if (node.namespace == null && _environment.atRoot) {
        if (_configuration.remove(node.name) case var override?
            when override.value != sassNull) {
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
          Deprecation.newGlobal);
    }

    var value = _withoutSlash(node.expression.accept(this), node.expression);
    _addExceptionSpan(node, () {
      _environment.setVariable(
          node.name, value, _expressionNode(node.expression),
          namespace: node.namespace, global: node.isGlobal);
    });
    return null;
  }

  Value? visitUseRule(UseRule node) {
    var configuration = const Configuration.empty();
    if (node.configuration.isNotEmpty) {
      var values = <String, ConfiguredValue>{};
      for (var variable in node.configuration) {
        var variableNodeWithSpan = _expressionNode(variable.expression);
        values[variable.name] = ConfiguredValue.explicit(
            _withoutSlash(
                variable.expression.accept(this), variableNodeWithSpan),
            variable.span,
            variableNodeWithSpan);
      }
      configuration = ExplicitConfiguration(values, node);
    }

    _loadModule(node.url, "@use", node, (module, firstLoad) {
      if (firstLoad) _registerCommentsForModule(module);
      _environment.addModule(module, node, namespace: node.namespace);
    }, configuration: configuration);
    _assertConfigurationIsEmpty(configuration);

    return null;
  }

  Value? visitWarnRule(WarnRule node) {
    var value = _addExceptionSpan(node, () => node.expression.accept(this));
    _logger.warn(
        value is SassString ? value.text : _serialize(value, node.expression),
        trace: _stackTrace(node.span));
    return null;
  }

  Value? visitWhileRule(WhileRule node) {
    return _environment.scope(() {
      while (node.condition.accept(this).isTruthy) {
        if (_handleReturn<Statement>(
                node.children, (child) => child.accept(this))
            case var result?) {
          return result;
        }
      }
      return null;
    }, semiGlobal: true, when: node.hasDeclarations);
  }

  // ## Expressions

  Value visitBinaryOperationExpression(BinaryOperationExpression node) {
    if (_stylesheet.plainCss &&
        node.operator != BinaryOperator.singleEquals &&
        node.operator != BinaryOperator.dividedBy) {
      throw _exception(
          "Operators aren't allowed in plain CSS.", node.operatorSpan);
    }

    return _addExceptionSpan(node, () {
      var left = node.left.accept(this);
      return switch (node.operator) {
        BinaryOperator.singleEquals =>
          left.singleEquals(node.right.accept(this)),
        BinaryOperator.or => left.isTruthy ? left : node.right.accept(this),
        BinaryOperator.and => left.isTruthy ? node.right.accept(this) : left,
        BinaryOperator.equals => SassBoolean(left == node.right.accept(this)),
        BinaryOperator.notEquals =>
          SassBoolean(left != node.right.accept(this)),
        BinaryOperator.greaterThan => left.greaterThan(node.right.accept(this)),
        BinaryOperator.greaterThanOrEquals =>
          left.greaterThanOrEquals(node.right.accept(this)),
        BinaryOperator.lessThan => left.lessThan(node.right.accept(this)),
        BinaryOperator.lessThanOrEquals =>
          left.lessThanOrEquals(node.right.accept(this)),
        BinaryOperator.plus => left.plus(node.right.accept(this)),
        BinaryOperator.minus => left.minus(node.right.accept(this)),
        BinaryOperator.times => left.times(node.right.accept(this)),
        BinaryOperator.dividedBy => _slash(left, node.right.accept(this), node),
        BinaryOperator.modulo => left.modulo(node.right.accept(this))
      };
    });
  }

  /// Returns the result of the SassScript `/` operation between [left] and
  /// [right] in [node].
  Value _slash(Value left, Value right, BinaryOperationExpression node) {
    var result = left.dividedBy(right);
    switch ((left, right)) {
      case (SassNumber left, SassNumber right)
          when node.allowsSlash &&
              _operandAllowsSlash(node.left) &&
              _operandAllowsSlash(node.right):
        return (result as SassNumber).withSlash(left, right);

      case (SassNumber(), SassNumber()):
        String recommendation(Expression expression) => switch (expression) {
              BinaryOperationExpression(
                operator: BinaryOperator.dividedBy,
                :var left,
                :var right
              ) =>
                "math.div(${recommendation(left)}, ${recommendation(right)})",
              ParenthesizedExpression() => expression.expression.toString(),
              _ => expression.toString()
            };

        _warn(
            "Using / for division outside of calc() is deprecated "
            "and will be removed in Dart Sass 2.0.0.\n"
            "\n"
            "Recommendation: ${recommendation(node)} or "
            "${expressionToCalc(node)}\n"
            "\n"
            "More info and automated migrator: "
            "https://sass-lang.com/d/slash-div",
            node.span,
            Deprecation.slashDiv);
        return result;

      case _:
        return result;
    }
  }

  /// Returns whether [node] can be used as a component of a slash-separated
  /// number.
  ///
  /// Although this logic is mostly resolved at parse-time, we can't tell
  /// whether operands will be evaluated as calculations until evaluation-time.
  bool _operandAllowsSlash(Expression node) =>
      node is! FunctionExpression ||
      (node.namespace == null &&
          const {
            "calc", "clamp", "hypot", "sin", "cos", "tan", "asin", "acos", //
            "atan", "sqrt", "exp", "sign", "mod", "rem", "atan2", "pow", "log"
          }.contains(node.name.toLowerCase()) &&
          _environment.getFunction(node.name) == null);

  Value visitValueExpression(ValueExpression node) => node.value;

  Value visitVariableExpression(VariableExpression node) {
    var result = _addExceptionSpan(node,
        () => _environment.getVariable(node.name, namespace: node.namespace));
    if (result != null) return result;
    throw _exception("Undefined variable.", node.span);
  }

  Value visitUnaryOperationExpression(UnaryOperationExpression node) {
    var operand = node.operand.accept(this);
    return _addExceptionSpan(node, () {
      return switch (node.operator) {
        UnaryOperator.plus => operand.unaryPlus(),
        UnaryOperator.minus => operand.unaryMinus(),
        UnaryOperator.divide => operand.unaryDivide(),
        UnaryOperator.not => operand.unaryNot()
      };
    });
  }

  SassBoolean visitBooleanExpression(BooleanExpression node) =>
      SassBoolean(node.value);

  Value visitIfExpression(IfExpression node) {
    var (positional, named) = _evaluateMacroArguments(node);
    _verifyArguments(positional.length, named, IfExpression.declaration, node);

    // ignore: prefer_is_empty
    var condition = positional.elementAtOrNull(0) ?? named["condition"]!;
    var ifTrue = positional.elementAtOrNull(1) ?? named["if-true"]!;
    var ifFalse = positional.elementAtOrNull(2) ?? named["if-false"]!;

    var result = condition.accept(this).isTruthy ? ifTrue : ifFalse;
    return _withoutSlash(result.accept(this), _expressionNode(result));
  }

  Value visitNullExpression(NullExpression node) => sassNull;

  SassNumber visitNumberExpression(NumberExpression node) =>
      SassNumber(node.value, node.unit);

  Value visitParenthesizedExpression(ParenthesizedExpression node) =>
      _stylesheet.plainCss
          ? throw _exception(
              "Parentheses aren't allowed in plain CSS.", node.span)
          : node.expression.accept(this);

  SassColor visitColorExpression(ColorExpression node) => node.value;

  SassList visitListExpression(ListExpression node) => SassList(
      node.contents.map((Expression expression) => expression.accept(this)),
      node.separator,
      brackets: node.hasBrackets);

  SassMap visitMapExpression(MapExpression node) {
    var map = <Value, Value>{};
    var keyNodes = <Value, AstNode>{};
    for (var (key, value) in node.pairs) {
      var keyValue = key.accept(this);
      var valueValue = value.accept(this);

      if (map.containsKey(keyValue)) {
        var oldValueSpan = keyNodes[keyValue]?.span;
        throw MultiSpanSassRuntimeException(
            'Duplicate key.',
            key.span,
            'second key',
            {if (oldValueSpan != null) oldValueSpan: 'first key'},
            _stackTrace(key.span));
      }
      map[keyValue] = valueValue;
      keyNodes[keyValue] = key;
    }
    return SassMap(map);
  }

  Value visitFunctionExpression(FunctionExpression node) {
    var function = _stylesheet.plainCss
        ? null
        : _addExceptionSpan(
            node,
            () =>
                _environment.getFunction(node.name, namespace: node.namespace));
    if (function == null) {
      if (node.namespace != null) {
        throw _exception("Undefined function.", node.span);
      }

      switch (node.name.toLowerCase()) {
        case "min" || "max" || "round" || "abs"
            when node.arguments.named.isEmpty &&
                node.arguments.rest == null &&
                node.arguments.positional
                    .every((argument) => argument.isCalculationSafe):
          return _visitCalculation(node, inLegacySassFunction: true);

        case "calc" ||
              "clamp" ||
              "hypot" ||
              "sin" ||
              "cos" ||
              "tan" ||
              "asin" ||
              "acos" ||
              "atan" ||
              "sqrt" ||
              "exp" ||
              "sign" ||
              "mod" ||
              "rem" ||
              "atan2" ||
              "pow" ||
              "log":
          return _visitCalculation(node);
      }

      function = (_stylesheet.plainCss ? null : _builtInFunctions[node.name]) ??
          PlainCssCallable(node.originalName);
    }

    var oldInFunction = _inFunction;
    _inFunction = true;
    var result = _addErrorSpan(
        node, () => _runFunctionCallable(node.arguments, function, node));
    _inFunction = oldInFunction;
    return result;
  }

  Value _visitCalculation(FunctionExpression node,
      {bool inLegacySassFunction = false}) {
    if (node.arguments.named.isNotEmpty) {
      throw _exception(
          "Keyword arguments can't be used with calculations.", node.span);
    } else if (node.arguments.rest != null) {
      throw _exception(
          "Rest arguments can't be used with calculations.", node.span);
    }

    _checkCalculationArguments(node);
    var arguments = [
      for (var argument in node.arguments.positional)
        _visitCalculationExpression(argument,
            inLegacySassFunction: inLegacySassFunction)
    ];
    if (_inSupportsDeclaration) {
      return SassCalculation.unsimplified(node.name, arguments);
    }

    try {
      return switch (node.name.toLowerCase()) {
        "calc" => SassCalculation.calc(arguments[0]),
        "sqrt" => SassCalculation.sqrt(arguments[0]),
        "sin" => SassCalculation.sin(arguments[0]),
        "cos" => SassCalculation.cos(arguments[0]),
        "tan" => SassCalculation.tan(arguments[0]),
        "asin" => SassCalculation.asin(arguments[0]),
        "acos" => SassCalculation.acos(arguments[0]),
        "atan" => SassCalculation.atan(arguments[0]),
        "abs" => SassCalculation.abs(arguments[0]),
        "exp" => SassCalculation.exp(arguments[0]),
        "sign" => SassCalculation.sign(arguments[0]),
        "min" => SassCalculation.min(arguments),
        "max" => SassCalculation.max(arguments),
        "hypot" => SassCalculation.hypot(arguments),
        "pow" =>
          SassCalculation.pow(arguments[0], arguments.elementAtOrNull(1)),
        "atan2" =>
          SassCalculation.atan2(arguments[0], arguments.elementAtOrNull(1)),
        "log" =>
          SassCalculation.log(arguments[0], arguments.elementAtOrNull(1)),
        "mod" =>
          SassCalculation.mod(arguments[0], arguments.elementAtOrNull(1)),
        "rem" =>
          SassCalculation.rem(arguments[0], arguments.elementAtOrNull(1)),
        "round" => SassCalculation.round(arguments[0],
            arguments.elementAtOrNull(1), arguments.elementAtOrNull(2)),
        "clamp" => SassCalculation.clamp(arguments[0],
            arguments.elementAtOrNull(1), arguments.elementAtOrNull(2)),
        _ => throw UnsupportedError('Unknown calculation name "${node.name}".')
      };
    } on SassScriptException catch (error, stackTrace) {
      // The simplification logic in the [SassCalculation] static methods will
      // throw an error if the arguments aren't compatible, but we have access
      // to the original spans so we can throw a more informative error.
      if (error.message.contains("compatible")) {
        _verifyCompatibleNumbers(arguments, node.arguments.positional);
      }
      throwWithTrace(_exception(error.message, node.span), error, stackTrace);
    }
  }

  /// Verifies that the calculation [node] has the correct number of arguments.
  void _checkCalculationArguments(FunctionExpression node) {
    void check([int? maxArgs]) {
      if (node.arguments.positional.isEmpty) {
        throw _exception("Missing argument.", node.span);
      } else if (maxArgs != null &&
          node.arguments.positional.length > maxArgs) {
        throw _exception(
            "Only $maxArgs ${pluralize('argument', maxArgs)} allowed, but "
                    "${node.arguments.positional.length} " +
                pluralize('was', node.arguments.positional.length,
                    plural: 'were') +
                " passed.",
            node.span);
      }
    }

    switch (node.name.toLowerCase()) {
      case "calc" ||
            "sqrt" ||
            "sin" ||
            "cos" ||
            "tan" ||
            "asin" ||
            "acos" ||
            "atan" ||
            "abs" ||
            "exp" ||
            "sign":
        check(1);
      case "min" || "max" || "hypot":
        check();
      case "pow" || "atan2" || "log" || "mod" || "rem":
        check(2);
      case "round" || "clamp":
        check(3);
      case _:
        throw UnsupportedError('Unknown calculation name "${node.name}".');
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
      if (args[i] case SassNumber arg when arg.hasComplexUnits) {
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
  /// If [inLegacySassFunction] is `true`, this allows unitless numbers to be added and
  /// subtracted with numbers with units, for backwards-compatibility with the
  /// old global `min()`, `max()`, `round()`, and `abs()` functions.
  Object _visitCalculationExpression(Expression node,
      {required bool inLegacySassFunction}) {
    switch (node) {
      case ParenthesizedExpression(expression: var inner):
        var result = _visitCalculationExpression(inner,
            inLegacySassFunction: inLegacySassFunction);
        return result is SassString
            ? SassString('(${result.text})', quotes: false)
            : result;

      case StringExpression() when node.isCalculationSafe:
        assert(!node.hasQuotes);
        return switch (node.text.asPlain?.toLowerCase()) {
          'pi' => SassNumber(math.pi),
          'e' => SassNumber(math.e),
          'infinity' => SassNumber(double.infinity),
          '-infinity' => SassNumber(double.negativeInfinity),
          'nan' => SassNumber(double.nan),
          _ => SassString(_performInterpolation(node.text), quotes: false)
        };

      case BinaryOperationExpression(:var operator, :var left, :var right):
        _checkWhitespaceAroundCalculationOperator(node);
        return _addExceptionSpan(
            node,
            () => SassCalculation.operateInternal(
                _binaryOperatorToCalculationOperator(operator, node),
                _visitCalculationExpression(left,
                    inLegacySassFunction: inLegacySassFunction),
                _visitCalculationExpression(right,
                    inLegacySassFunction: inLegacySassFunction),
                inLegacySassFunction: inLegacySassFunction,
                simplify: !_inSupportsDeclaration));

      case NumberExpression() ||
            VariableExpression() ||
            FunctionExpression() ||
            IfExpression():
        return switch (node.accept(this)) {
          SassNumber result => result,
          SassCalculation result => result,
          SassString result when !result.hasQuotes => result,
          var result => throw _exception(
              "Value $result can't be used in a calculation.", node.span)
        };

      case ListExpression(
          hasBrackets: false,
          separator: ListSeparator.space,
          contents: [_, _, ...]
        ):
        var elements = [
          for (var element in node.contents)
            _visitCalculationExpression(element,
                inLegacySassFunction: inLegacySassFunction)
        ];

        _checkAdjacentCalculationValues(elements, node);

        for (var i = 0; i < elements.length; i++) {
          if (elements[i] is CalculationOperation &&
              node.contents[i] is ParenthesizedExpression) {
            elements[i] = SassString("(${elements[i]})", quotes: false);
          }
        }

        return SassString(elements.join(' '), quotes: false);

      case _:
        assert(!node.isCalculationSafe);
        throw _exception(
            "This expression can't be used in a calculation.", node.span);
    }
  }

  /// Throws an error if [node] requires whitespace around its operator in a
  /// calculation but doesn't have it.
  void _checkWhitespaceAroundCalculationOperator(
      BinaryOperationExpression node) {
    if (node.operator != BinaryOperator.plus &&
        node.operator != BinaryOperator.minus) {
      return;
    }

    // We _should_ never be able to violate these conditions since we always
    // parse binary operations from a single file, but it's better to be safe
    // than have this crash bizarrely.
    if (node.left.span.file != node.right.span.file) return;
    if (node.left.span.end.offset >= node.right.span.start.offset) return;

    var textBetweenOperands = node.left.span.file
        .getText(node.left.span.end.offset, node.right.span.start.offset);
    var first = textBetweenOperands.codeUnitAt(0);
    var last = textBetweenOperands.codeUnitAt(textBetweenOperands.length - 1);
    if (!(first.isWhitespace || first == $slash) ||
        !(last.isWhitespace || last == $slash)) {
      throw _exception(
          '"+" and "-" must be surrounded by whitespace in calculations.',
          node.operatorSpan);
    }
  }

  /// Returns the [CalculationOperator] that corresponds to [operator].
  CalculationOperator _binaryOperatorToCalculationOperator(
          BinaryOperator operator, BinaryOperationExpression node) =>
      switch (operator) {
        BinaryOperator.plus => CalculationOperator.plus,
        BinaryOperator.minus => CalculationOperator.minus,
        BinaryOperator.times => CalculationOperator.times,
        BinaryOperator.dividedBy => CalculationOperator.dividedBy,
        _ => throw _exception(
            "This operation can't be used in a calculation.", node.operatorSpan)
      };

  /// Throws an error if [elements] contains two adjacent non-string values.
  void _checkAdjacentCalculationValues(
      List<Object> elements, ListExpression node) {
    assert(elements.length > 1);

    for (var i = 1; i < elements.length; i++) {
      var previous = elements[i - 1];
      var current = elements[i];
      if (previous is SassString || current is SassString) continue;

      var previousNode = node.contents[i - 1];
      var currentNode = node.contents[i];
      if (currentNode
          case UnaryOperationExpression(
                operator: UnaryOperator.minus || UnaryOperator.plus
              ) ||
              NumberExpression(value: < 0)) {
        // `calc(1 -2)` parses as a space-separated list whose second value is a
        // unary operator or a negative number, but just saying it's an invalid
        // expression doesn't help the user understand what's going wrong. We
        // add special case error handling to help clarify the issue.
        throw _exception(
            '"+" and "-" must be surrounded by whitespace in calculations.',
            currentNode.span.subspan(0, 1));
      } else {
        throw _exception('Missing math operator.',
            previousNode.span.expand(currentNode.span));
      }
    }
  }

  Value visitInterpolatedFunctionExpression(
      InterpolatedFunctionExpression node) {
    var function = PlainCssCallable(_performInterpolation(node.name));
    var oldInFunction = _inFunction;
    _inFunction = true;
    var result = _addErrorSpan(
        node, () => _runFunctionCallable(node.arguments, function, node));
    _inFunction = oldInFunction;
    return result;
  }

  /// Evaluates the arguments in [arguments] as applied to [callable], and
  /// invokes [run] in a scope with those arguments defined.
  V _runUserDefinedCallable<V extends Value?>(
      ArgumentInvocation arguments,
      UserDefinedCallable<Environment> callable,
      AstNode nodeWithSpan,
      V run()) {
    // TODO(nweiz): Set [trackSpans] to `null` once we're no longer emitting
    // deprecation warnings for /-as-division.
    var evaluated = _evaluateArguments(arguments);

    var name = callable.name;
    if (name != "@content") name += "()";

    var oldCallable = _currentCallable;
    _currentCallable = callable;
    var result = _withStackFrame(name, nodeWithSpan, () {
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
            _environment.setLocalVariable(declaredArguments[i].name,
                evaluated.positional[i], evaluated.positionalNodes[i]);
          }

          for (var i = evaluated.positional.length;
              i < declaredArguments.length;
              i++) {
            var argument = declaredArguments[i];
            var value = evaluated.named.remove(argument.name) ??
                _withoutSlash(argument.defaultValue!.accept<Value>(this),
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

          var result = run();

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
    _currentCallable = oldCallable;
    return result;
  }

  /// Evaluates [arguments] as applied to [callable].
  Value _runFunctionCallable(
      ArgumentInvocation arguments, Callable? callable, AstNode nodeWithSpan) {
    if (callable is BuiltInCallable) {
      return _withoutSlash(
          _runBuiltInCallable(arguments, callable, nodeWithSpan), nodeWithSpan);
    } else if (callable is UserDefinedCallable<Environment>) {
      return _runUserDefinedCallable(arguments, callable, nodeWithSpan, () {
        for (var statement in callable.declaration.children) {
          var returnValue = statement.accept(this);
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
      try {
        var first = true;
        for (var argument in arguments.positional) {
          if (first) {
            first = false;
          } else {
            buffer.write(", ");
          }

          buffer.write(_evaluateToCss(argument));
        }

        var restArg = arguments.rest;
        if (restArg != null) {
          var rest = restArg.accept(this);
          if (!first) buffer.write(", ");
          buffer.write(_serialize(rest, restArg));
        }
      } on SassRuntimeException catch (error) {
        if (!error.message.endsWith("isn't a valid CSS value.")) rethrow;
        throw MultiSpanSassRuntimeException(
            error.message,
            error.span,
            "value",
            {nodeWithSpan.span: "unknown function treated as plain CSS"},
            error.trace);
      }
      buffer.writeCharCode($rparen);

      return SassString(buffer.toString(), quotes: false);
    } else {
      throw ArgumentError('Unknown callable type ${callable.runtimeType}.');
    }
  }

  /// Evaluates [invocation] as applied to [callable], and invokes [callable]'s
  /// body.
  Value _runBuiltInCallable(ArgumentInvocation arguments,
      BuiltInCallable callable, AstNode nodeWithSpan) {
    var evaluated = _evaluateArguments(arguments);

    var oldCallableNode = _callableNode;
    _callableNode = nodeWithSpan;

    var namedSet = MapKeySet(evaluated.named);
    var (overload, callback) =
        callable.callbackFor(evaluated.positional.length, namedSet);
    _addExceptionSpan(nodeWithSpan,
        () => overload.verify(evaluated.positional.length, namedSet));

    var declaredArguments = overload.arguments;
    for (var i = evaluated.positional.length;
        i < declaredArguments.length;
        i++) {
      var argument = declaredArguments[i];
      evaluated.positional.add(evaluated.named.remove(argument.name) ??
          _withoutSlash(
              argument.defaultValue!.accept(this), argument.defaultValue!));
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
      result =
          _addExceptionSpan(nodeWithSpan, () => callback(evaluated.positional));
    } on SassException {
      rethrow;
    } catch (error, stackTrace) {
      String? message;
      try {
        message = (error as dynamic).message as String;
      } catch (_) {
        message = error.toString();
      }
      throwWithTrace(_exception(message, nodeWithSpan.span), error, stackTrace);
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
  _ArgumentResults _evaluateArguments(ArgumentInvocation arguments) {
    // TODO(nweiz): This used to avoid tracking source spans for arguments if
    // [_sourceMap]s was false or it was being called from
    // [_runBuiltInCallable]. We always have to track them now to produce better
    // warnings for /-as-division, but once those warnings are gone we should go
    // back to tracking conditionally.

    var positional = <Value>[];
    var positionalNodes = <AstNode>[];
    for (var expression in arguments.positional) {
      var nodeForSpan = _expressionNode(expression);
      positional.add(_withoutSlash(expression.accept(this), nodeForSpan));
      positionalNodes.add(nodeForSpan);
    }

    var named = <String, Value>{};
    var namedNodes = <String, AstNode>{};
    for (var (name, value) in arguments.named.pairs) {
      var nodeForSpan = _expressionNode(value);
      named[name] = _withoutSlash(value.accept(this), nodeForSpan);
      namedNodes[name] = nodeForSpan;
    }

    var restArgs = arguments.rest;
    if (restArgs == null) {
      return (
        positional: positional,
        positionalNodes: positionalNodes,
        named: named,
        namedNodes: namedNodes,
        separator: ListSeparator.undecided
      );
    }

    var rest = restArgs.accept(this);
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
      return (
        positional: positional,
        positionalNodes: positionalNodes,
        named: named,
        namedNodes: namedNodes,
        separator: separator
      );
    }

    var keywordRest = keywordRestArgs.accept(this);
    var keywordRestNodeForSpan = _expressionNode(keywordRestArgs);
    if (keywordRest is SassMap) {
      _addRestMap(named, keywordRest, keywordRestArgs, (value) => value);
      namedNodes.addAll({
        for (var key in keywordRest.contents.keys)
          (key as SassString).text: keywordRestNodeForSpan
      });
      return (
        positional: positional,
        positionalNodes: positionalNodes,
        named: named,
        namedNodes: namedNodes,
        separator: separator
      );
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
  (List<Expression> positional, Map<String, Expression> named)
      _evaluateMacroArguments(CallableInvocation invocation) {
    var restArgs_ = invocation.arguments.rest;
    if (restArgs_ == null) {
      return (invocation.arguments.positional, invocation.arguments.named);
    }
    var restArgs = restArgs_; // dart-lang/sdk#45348

    var positional = invocation.arguments.positional.toList();
    var named = Map.of(invocation.arguments.named);
    var rest = restArgs.accept(this);
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
    if (keywordRestArgs_ == null) return (positional, named);
    var keywordRestArgs = keywordRestArgs_; // dart-lang/sdk#45348

    var keywordRest = keywordRestArgs.accept(this);
    var keywordRestNodeForSpan = _expressionNode(keywordRestArgs);
    if (keywordRest is SassMap) {
      _addRestMap(
          named,
          keywordRest,
          invocation,
          (value) => ValueExpression(
              _withoutSlash(value, keywordRestNodeForSpan),
              keywordRestArgs.span));
      return (positional, named);
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

  Value visitSelectorExpression(SelectorExpression node) =>
      _styleRuleIgnoringAtRoot?.originalSelector.asSassList ?? sassNull;

  SassString visitStringExpression(StringExpression node) {
    // Don't use [performInterpolation] here because we need to get the raw text
    // from strings, rather than the semantic value.
    var oldInSupportsDeclaration = _inSupportsDeclaration;
    _inSupportsDeclaration = false;
    var result = SassString(
        [
          for (var value in node.text.contents)
            switch (value) {
              String() => value,
              Expression() => switch (value.accept(this)) {
                  SassString(:var text) => text,
                  var result => _serialize(result, value, quote: false)
                },
              _ => throw UnsupportedError("Unknown interpolation value $value")
            }
        ].join(),
        quotes: node.hasQuotes);
    _inSupportsDeclaration = oldInSupportsDeclaration;
    return result;
  }

  SassString visitSupportsExpression(SupportsExpression expression) =>
      SassString(_visitSupportsCondition(expression.condition), quotes: false);

  // ## Plain CSS

  // These methods are used when evaluating CSS syntax trees from `@import`ed
  // stylesheets that themselves contain `@use` rules, and CSS included via the
  // `load-css()` function. When we load a module using one of these constructs,
  // we first convert it to CSS (we can't evaluate it as Sass directly because
  // it may be used elsewhere and it must only be evaluated once). Then we
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
      return;
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
        parsedAsCustomProperty: node.parsedAsCustomProperty,
        valueSpanForMap: node.valueSpanForMap));
  }

  void visitCssImport(CssImport node) {
    // NOTE: this logic is largely duplicated in [_visitStaticImport]. Most
    // changes here should be mirrored there.

    var modifiableNode =
        ModifiableCssImport(node.url, node.span, modifiers: node.modifiers);
    if (_parent != _root) {
      _parent.addChild(modifiableNode);
    } else if (_endOfImports == _root.children.length) {
      _root.addChild(modifiableNode);
      _endOfImports++;
    } else {
      (_outOfOrderImports ??= []).add(modifiableNode);
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

    var mergedQueries = _mediaQueries.andThen(
        (mediaQueries) => _mergeMediaQueries(mediaQueries, node.queries));
    if (mergedQueries != null && mergedQueries.isEmpty) return;

    var mergedSources = mergedQueries == null
        ? const <CssMediaQuery>{}
        : {..._mediaQuerySources!, ..._mediaQueries!, ...node.queries};

    _withParent(
        ModifiableCssMediaRule(mergedQueries ?? node.queries, node.span), () {
      _withMediaQueries(mergedQueries ?? node.queries, mergedSources, () {
        if (_styleRule case var styleRule?) {
          // If we're in a style rule, copy it into the media query so that
          // declarations immediately inside @media have somewhere to go.
          //
          // For example, "a {@media screen {b: c}}" should produce
          // "@media screen {a {b: c}}".
          _withParent(styleRule.copyWithoutChildren(), () {
            for (var child in node.children) {
              child.accept(this);
            }
          }, scopeWhen: false);
        } else {
          for (var child in node.children) {
            child.accept(this);
          }
        }
      });
    },
        through: (node) =>
            node is CssStyleRule ||
            (mergedSources.isNotEmpty &&
                node is CssMediaRule &&
                node.queries.every(mergedSources.contains)),
        scopeWhen: false);
  }

  void visitCssStyleRule(CssStyleRule node) {
    // NOTE: this logic is largely duplicated in [visitStyleRule]. Most changes
    // here should be mirrored there.

    if (_declarationName != null) {
      throw _exception(
          "Style rules may not be used within nested declarations.", node.span);
    }

    var styleRule = _styleRule;
    var originalSelector = node.selector.resolveParentSelectors(
        styleRule?.originalSelector,
        implicitParent: !_atRootExcludingStyleRule);
    var selector = _extensionStore.addSelector(originalSelector, _mediaQueries);
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

    if (_parent.children case [..., var lastChild] when styleRule == null) {
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
      if (_styleRule case var styleRule?) {
        // If we're in a style rule, copy it into the supports rule so that
        // declarations immediately inside @supports have somewhere to go.
        //
        // For example, "a {@supports (a: b) {b: c}}" should produce "@supports
        // (a: b) {a {b: c}}".
        _withParent(styleRule.copyWithoutChildren(), () {
          for (var child in node.children) {
            child.accept(this);
          }
        });
      } else {
        for (var child in node.children) {
          child.accept(this);
        }
      }
    }, through: (node) => node is CssStyleRule, scopeWhen: false);
  }

  // ## Utilities

  /// Runs [callback] for each value in [list] until it returns a [Value].
  ///
  /// Returns the value returned by [callback], or `null` if it only ever
  /// returned `null`.
  Value? _handleReturn<T>(List<T> list, Value? callback(T value)) {
    for (var value in list) {
      if (callback(value) case var result?) return result;
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
    var (result, _) = _performInterpolationHelper(interpolation,
        sourceMap: true, warnForColor: warnForColor);
    return result;
  }

  /// Like [_performInterpolation], but also returns a [InterpolationMap] that
  /// can map spans from the resulting string back to the original
  /// [interpolation].
  (String, InterpolationMap) _performInterpolationWithMap(
      Interpolation interpolation,
      {bool warnForColor = false}) {
    var (result, map) = _performInterpolationHelper(interpolation,
        sourceMap: true, warnForColor: warnForColor);
    return (result, map!);
  }

  /// A helper that implements the core logic of both [_performInterpolation]
  /// and [_performInterpolationWithMap].
  (String, InterpolationMap?) _performInterpolationHelper(
      Interpolation interpolation,
      {required bool sourceMap,
      bool warnForColor = false}) {
    var targetLocations = sourceMap ? <SourceLocation>[] : null;
    var oldInSupportsDeclaration = _inSupportsDeclaration;
    _inSupportsDeclaration = false;
    var buffer = StringBuffer();
    var first = true;
    for (var value in interpolation.contents) {
      if (!first) targetLocations?.add(SourceLocation(buffer.length));
      first = false;

      if (value is String) {
        buffer.write(value);
        continue;
      }

      var expression = value as Expression;
      var result = expression.accept(this);

      if (warnForColor && namesByColor.containsKey(result)) {
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

      buffer.write(_serialize(result, expression, quote: false));
    }
    _inSupportsDeclaration = oldInSupportsDeclaration;

    return (
      buffer.toString(),
      targetLocations.andThen(
          (targetLocations) => InterpolationMap(interpolation, targetLocations))
    );
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
  T _withParent<S extends ModifiableCssParentNode, T>(S node, T callback(),
      {bool through(CssNode node)?, bool scopeWhen = true}) {
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
  void _addChild(ModifiableCssNode node, {bool through(CssNode node)?}) {
    // Go up through parents that match [through].
    var parent = _parent;
    if (through != null) {
      while (through(parent)) {
        if (parent.parent case var grandparent?) {
          parent = grandparent;
        } else {
          throw ArgumentError(
              "through() must return false for at least one parent of $node.");
        }
      }

      // If the parent has a (visible) following sibling, we shouldn't add to
      // the parent. Instead, we should create a copy and add it after the
      // interstitial sibling.
      if (parent.hasFollowingSibling) {
        // A node with siblings must have a parent
        var grandparent = parent.parent!;
        if (parent.equalsIgnoringChildren(grandparent.children.last)) {
          // If we've already made a copy of [parent] and nothing else has been
          // added after it, re-use it.
          parent = grandparent.children.last as ModifiableCssParentNode;
        } else {
          parent = parent.copyWithoutChildren();
          grandparent.addChild(parent);
        }
      }
    }

    parent.addChild(node);
  }

  /// Runs [callback] with [rule] as the current style rule.
  T _withStyleRule<T>(ModifiableCssStyleRule rule, T callback()) {
    var oldRule = _styleRuleIgnoringAtRoot;
    _styleRuleIgnoringAtRoot = rule;
    var result = callback();
    _styleRuleIgnoringAtRoot = oldRule;
    return result;
  }

  /// Runs [callback] with [queries] as the current media queries.
  ///
  /// This also sets [sources] as the current set of media queries that were
  /// merged together to create [queries]. This is used to determine when it's
  /// safe to bubble one query through another.
  T _withMediaQueries<T>(
      List<CssMediaQuery>? queries, Set<CssMediaQuery>? sources, T callback()) {
    var oldMediaQueries = _mediaQueries;
    var oldSources = _mediaQuerySources;
    _mediaQueries = queries;
    _mediaQuerySources = sources;
    var result = callback();
    _mediaQueries = oldMediaQueries;
    _mediaQuerySources = oldSources;
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
    _stack.add((_member, nodeWithSpan));
    var oldMember = _member;
    _member = member;
    var result = callback();
    _member = oldMember;
    _stack.removeLast();
    return result;
  }

  /// Like [Value.withoutSlash], but produces a deprecation warning if [value]
  /// was a slash-separated number.
  Value _withoutSlash(Value value, AstNode nodeForSpan) {
    if (value case SassNumber(asSlash: _?)) {
      String recommendation(SassNumber number) => switch (number.asSlash) {
            (var before, var after) =>
              "math.div(${recommendation(before)}, ${recommendation(after)})",
            _ => number.toString()
          };

      _warn(
          "Using / for division is deprecated and will be removed in Dart Sass "
          "2.0.0.\n"
          "\n"
          "Recommendation: ${recommendation(value)}\n"
          "\n"
          "More info and automated migrator: "
          "https://sass-lang.com/d/slash-div",
          nodeForSpan.span,
          Deprecation.slashDiv);
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
      for (var (member, nodeWithSpan) in _stack)
        _stackFrame(member, nodeWithSpan.span),
      if (span != null) _stackFrame(_member, span)
    ];
    return Trace(frames.reversed);
  }

  /// Emits a warning with the given [message] about the given [span].
  void _warn(String message, FileSpan span, [Deprecation? deprecation]) {
    if (_quietDeps &&
        (_inDependency || (_currentCallable?.inDependency ?? false))) {
      return;
    }

    if (!_warningsEmitted.add((message, span))) return;
    var trace = _stackTrace(span);
    if (deprecation == null) {
      _logger.warn(message, span: span, trace: trace);
    } else {
      _logger.warnForDeprecation(deprecation, message,
          span: span, trace: trace);
    }
  }

  /// Returns a [SassRuntimeException] with the given [message].
  ///
  /// If [span] is passed, it's used for the innermost stack frame.
  SassRuntimeException _exception(String message, [FileSpan? span]) =>
      SassRuntimeException(
          message, span ?? _stack.last.$2.span, _stackTrace(span));

  /// Returns a [MultiSpanSassRuntimeException] with the given [message],
  /// [primaryLabel], and [secondaryLabels].
  ///
  /// The primary span is taken from the current stack trace span.
  SassRuntimeException _multiSpanException(String message, String primaryLabel,
          Map<FileSpan, String> secondaryLabels) =>
      MultiSpanSassRuntimeException(message, _stack.last.$2.span, primaryLabel,
          secondaryLabels, _stackTrace());

  /// Runs [callback], and converts any [SassScriptException]s it throws to
  /// [SassRuntimeException]s with [nodeWithSpan]'s source span.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  ///
  /// If [addStackFrame] is true (the default), this will add an innermost stack
  /// frame for [nodeWithSpan]. Otherwise, it will use the existing stack as-is.
  T _addExceptionSpan<T>(AstNode nodeWithSpan, T callback(),
      {bool addStackFrame = true}) {
    try {
      return callback();
    } on SassScriptException catch (error, stackTrace) {
      throwWithTrace(
          error
              .withSpan(nodeWithSpan.span)
              .withTrace(_stackTrace(addStackFrame ? nodeWithSpan.span : null)),
          error,
          stackTrace);
    }
  }

  /// Runs [callback], and converts any [SassException]s that aren't already
  /// [SassRuntimeException]s to [SassRuntimeException]s with the current stack
  /// trace.
  T _addExceptionTrace<T>(T callback()) {
    try {
      return callback();
    } on SassRuntimeException {
      rethrow;
    } on SassException catch (error, stackTrace) {
      throwWithTrace(
          error.withTrace(_stackTrace(error.span)), error, stackTrace);
    }
  }

  /// Runs [callback], and converts any [SassRuntimeException]s containing an
  /// @error to throw a more relevant [SassRuntimeException] with [nodeWithSpan]'s
  /// source span.
  T _addErrorSpan<T>(AstNode nodeWithSpan, T callback()) {
    try {
      return callback();
    } on SassRuntimeException catch (error, stackTrace) {
      if (!error.span.text.startsWith("@error")) rethrow;
      throwWithTrace(
          SassRuntimeException(error.message, nodeWithSpan.span, _stackTrace()),
          error,
          stackTrace);
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
final class _ImportedCssVisitor implements ModifiableCssVisitor<void> {
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

/// An implementation of [EvaluationContext] using the information available in
/// [_EvaluateVisitor].
final class _EvaluationContext implements EvaluationContext {
  /// The visitor backing this context.
  final _EvaluateVisitor _visitor;

  /// The AST node whose span should be used for [warn] if no other span is
  /// available.
  final AstNode _defaultWarnNodeWithSpan;

  _EvaluationContext(this._visitor, this._defaultWarnNodeWithSpan);

  FileSpan get currentCallableSpan {
    if (_visitor._callableNode case var callableNode?) return callableNode.span;
    throw StateError("No Sass callable is currently being evaluated.");
  }

  void warn(String message, [Deprecation? deprecation]) {
    _visitor._warn(
        message,
        _visitor._importSpan ??
            _visitor._callableNode?.span ??
            _defaultWarnNodeWithSpan.span,
        deprecation);
  }
}

/// The result of evaluating arguments to a function or mixin.
typedef _ArgumentResults = ({
  /// Arguments passed by position.
  List<Value> positional,

  /// The [AstNode]s that hold the spans for each [positional] argument.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  List<AstNode> positionalNodes,

  /// Arguments passed by name.
  Map<String, Value> named,

  /// The [AstNode]s that hold the spans for each [named] argument.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  Map<String, AstNode> namedNodes,

  /// The separator used for the rest argument list, if any.
  ListSeparator separator
});

/// The result of loading a stylesheet via [Evaluator._loadStylesheet].
typedef _LoadedStylesheet = (
  /// The stylesheet itself.
  Stylesheet stylesheet, {
  /// The importer that was used to load the stylesheet.
  ///
  /// This is `null` when running in Node Sass compatibility mode.
  Importer? importer,

  /// Whether this load counts as a dependency.
  ///
  /// That is, whether this was (transitively) loaded through a load path or
  /// importer rather than relative to the entrypoint.
  bool isDependency
});
