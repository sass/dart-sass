// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_environment.dart.
// See tool/grind/synchronize.dart for details.
//
// Checksum: 23c920bd76d38c4ccf2024a0740aeae9672143d0
//
// ignore_for_file: unused_import

import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'ast/css.dart';
import 'ast/node.dart';
import 'module.dart';
import 'callable.dart';
import 'exception.dart';
import 'extend/extender.dart';
import 'functions.dart';
import 'util/public_member_map.dart';
import 'utils.dart';
import 'value.dart';
import 'visitor/clone_css.dart';

/// The lexical environment in which Sass is executed.
///
/// This tracks lexically-scoped information, such as variables, functions, and
/// mixins.
class Environment {
  /// The modules used in the current scope, indexed by their namespaces.
  final Map<String, Module> _modules;

  /// The namespaceless modules used in the current scope.
  ///
  /// This is `null` if there are no namespaceless modules.
  Set<Module> _globalModules;

  /// Modules from both [_modules] and [_global], in the order in which they
  /// were `@use`d.
  final List<Module> _allModules;

  /// A list of variables defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared variables to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Value>> _variables;

  /// The nodes where each variable in [_variables] was defined.
  ///
  /// This is `null` if source mapping is disabled.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final List<Map<String, AstNode>> _variableNodes;

  /// A map of variable names to their indices in [_variables].
  ///
  /// This map is *normalized*, meaning that it treats hyphens and underscores
  /// in its keys interchangeably.
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _variableIndices;

  /// A list of functions defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared functions to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Callable>> _functions;

  /// A map of function names to their indices in [_functions].
  ///
  /// This map is *normalized*, meaning that it treats hyphens and underscores
  /// in its keys interchangeably.
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _functionIndices;

  /// A list of mixins defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared mixins to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Callable>> _mixins;

  /// A map of mixin names to their indices in [_mixins].
  ///
  /// This map is *normalized*, meaning that it treats hyphens and underscores
  /// in its keys interchangeably.
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _mixinIndices;

  /// The content block passed to the lexically-enclosing mixin, or `null` if
  /// this is not in a mixin, or if no content block was passed.
  UserDefinedCallable<Environment> get content => _content;
  UserDefinedCallable<Environment> _content;

  /// Whether the environment is lexically within a mixin.
  bool get inMixin => _inMixin;
  var _inMixin = false;

  /// Whether the environment is currently in a global or semi-global scope.
  ///
  /// A semi-global scope can assign to global variables, but it doesn't declare
  /// them by default.
  var _inSemiGlobalScope = true;

  /// The name of the last variable that was accessed.
  ///
  /// This is cached to speed up repeated references to the same variable, as
  /// well as references to the last variable's [FileSpan].
  String _lastVariableName;

  /// The index in [_variables] of the last variable that was accessed.
  int _lastVariableIndex;

  /// Creates an [Environment].
  ///
  /// If [sourceMap] is `true`, this tracks variables' source locations
  Environment({bool sourceMap = false})
      : _modules = {},
        _globalModules = null,
        _allModules = [],
        _variables = [normalizedMap()],
        _variableNodes = sourceMap ? [normalizedMap()] : null,
        _variableIndices = normalizedMap(),
        _functions = [normalizedMap()],
        _functionIndices = normalizedMap(),
        _mixins = [normalizedMap()],
        _mixinIndices = normalizedMap() {
    coreFunctions.forEach(setFunction);
  }

  Environment._(
      this._modules,
      this._globalModules,
      this._allModules,
      this._variables,
      this._variableNodes,
      this._functions,
      this._mixins,
      this._content)
      // Lazily fill in the indices rather than eagerly copying them from the
      // existing environment in closure() because the copying took a lot of
      // time and was rarely helpful. This saves a bunch of time on Susy's
      // tests.
      : _variableIndices = normalizedMap(),
        _functionIndices = normalizedMap(),
        _mixinIndices = normalizedMap();

  /// Creates a closure based on this environment.
  ///
  /// Any scope changes in this environment will not affect the closure.
  /// However, any new declarations or assignments in scopes that are visible
  /// when the closure was created will be reflected.
  Environment closure() => Environment._(
      _modules,
      _globalModules,
      _allModules,
      _variables.toList(),
      _variableNodes?.toList(),
      _functions.toList(),
      _mixins.toList(),
      _content);

  /// Returns a new global environment.
  ///
  /// The returned environment shares this environment's global variables,
  /// functions, and mixins, but not its modules.
  Environment global() => Environment._(
      {},
      null,
      [],
      _variables.toList(),
      _variableNodes?.toList(),
      _functions.toList(),
      _mixins.toList(),
      _content);

  /// Adds [module] to the set of modules visible in this environment.
  ///
  /// If [namespace] is passed, the module is made available under that
  /// namespace.
  ///
  /// Throws a [SassScriptException] if there's already a module with the given
  /// [namespace], or if [namespace] is `null` and [module] defines a variable
  /// with the same name as a variable defined in this environment.
  void addModule(Module module, {String namespace}) {
    if (namespace == null) {
      _globalModules ??= Set();
      _globalModules.add(module);
      _allModules.add(module);

      for (var name in _variables.first.keys) {
        if (module.variables.containsKey(name)) {
          throw SassScriptException(
              'This module and the new module both define a variable named '
              '"\$$name".');
        }
      }
    } else {
      if (_modules.containsKey(namespace)) {
        throw SassScriptException(
            "There's already a module with namespace \"$namespace\".");
      }

      _modules[namespace] = module;
      _allModules.add(module);
    }
  }

  /// Returns the value of the variable named [name], optionally with the given
  /// [namespace], or `null` if no such variable is declared.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose variables named [name].
  Value getVariable(String name, {String namespace}) {
    if (namespace != null) return _getModule(namespace).variables[name];

    if (_lastVariableName == name) {
      return _variables[_lastVariableIndex][name] ??
          _getVariableFromGlobalModule(name);
    }

    var index = _variableIndices[name];
    if (index != null) {
      _lastVariableName = name;
      _lastVariableIndex = index;
      return _variables[index][name] ?? _getVariableFromGlobalModule(name);
    }

    index = _variableIndex(name);
    if (index == null) return _getVariableFromGlobalModule(name);

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    return _variables[index][name] ?? _getVariableFromGlobalModule(name);
  }

  /// Returns the value of the variable named [name] from a namespaceless
  /// module, or `null` if no such variable is declared in any namespaceless
  /// module.
  Value _getVariableFromGlobalModule(String name) =>
      _fromOneModule("variable", "\$$name", (module) => module.variables[name]);

  /// Returns the node for the variable named [name], or `null` if no such
  /// variable is declared.
  ///
  /// This node is intended as a proxy for the [FileSpan] indicating where the
  /// variable's value originated. It's returned as an [AstNode] rather than a
  /// [FileSpan] so we can avoid calling [AstNode.span] if the span isn't
  /// required, since some nodes need to do real work to manufacture a source
  /// span.
  AstNode getVariableNode(String name, {String namespace}) {
    if (namespace != null) return _getModule(namespace).variableNodes[name];

    if (_lastVariableName == name) {
      return _variableNodes[_lastVariableIndex][name] ??
          _getVariableNodeFromGlobalModule(name);
    }

    var index = _variableIndices[name];
    if (index != null) {
      _lastVariableName = name;
      _lastVariableIndex = index;
      return _variableNodes[index][name] ??
          _getVariableNodeFromGlobalModule(name);
    }

    index = _variableIndex(name);
    if (index == null) return _getVariableNodeFromGlobalModule(name);

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    return _variableNodes[index][name] ??
        _getVariableNodeFromGlobalModule(name);
  }

  /// Returns the node for the variable named [name] from a namespaceless
  /// module, or `null` if no such variable is declared.
  ///
  /// This node is intended as a proxy for the [FileSpan] indicating where the
  /// variable's value originated. It's returned as an [AstNode] rather than a
  /// [FileSpan] so we can avoid calling [AstNode.span] if the span isn't
  /// required, since some nodes need to do real work to manufacture a source
  /// span.
  AstNode _getVariableNodeFromGlobalModule(String name) {
    // There isn't a real variable defined as this index, but it will cause
    // [getVariable] to short-circuit and get to this function faster next time
    // the variable is accessed.
    _lastVariableName = name;
    _lastVariableIndex = 0;

    if (_globalModules == null) return null;

    // We don't need to worry about multiple modules defining the same variable,
    // because that's already been checked by [getVariable].
    for (var module in _globalModules) {
      var value = module.variableNodes[name];
      if (value != null) return value;
    }
    return null;
  }

  /// Returns whether a variable named [name] exists.
  bool variableExists(String name) => getVariable(name) != null;

  /// Returns whether a global variable named [name] exists.
  bool globalVariableExists(String name) {
    if (_variables.first.containsKey(name)) return true;
    return _getVariableFromGlobalModule(name) != null;
  }

  /// Returns the index of the last map in [_variables] that has a [name] key,
  /// or `null` if none exists.
  int _variableIndex(String name) {
    for (var i = _variables.length - 1; i >= 0; i--) {
      if (_variables[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Sets the variable named [name] to [value], associated with
  /// [nodeWithSpan]'s source span.
  ///
  /// If [namespace] is passed, this sets the variable in the module with the
  /// given namespace, if that module exposes a variable with that name.
  ///
  /// If [global] is `true`, this sets the variable at the top-level scope.
  /// Otherwise, if the variable was already defined, it'll set it in the
  /// previous scope. If it's undefined, it'll set it in the current scope.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  ///
  /// Throws a [SassScriptException] if [namespace] is passed but no module is
  /// defined with the given namespace, if no variable with the given [name] is
  /// defined in module with the given namespace, or if no [namespace] is passed
  /// and multiple global modules define variables named [name].
  void setVariable(String name, Value value, AstNode nodeWithSpan,
      {String namespace, bool global = false}) {
    if (namespace != null) {
      _getModule(namespace).setVariable(name, value, nodeWithSpan);
      return;
    }

    if (global || _variables.length == 1) {
      // Don't set the index if there's already a variable with the given name,
      // since local accesses should still return the local variable.
      _variableIndices.putIfAbsent(name, () {
        _lastVariableName = name;
        _lastVariableIndex = 0;
        return 0;
      });

      // If this module doesn't already contain a variable named [name], try
      // setting it in a global module.
      if (!_variables.first.containsKey(name) && _globalModules != null) {
        var moduleWithName = _fromOneModule("variable", "\$$name",
            (module) => module.variables.containsKey(name) ? module : null);
        if (moduleWithName != null) {
          moduleWithName.setVariable(name, value, nodeWithSpan);
          return;
        }
      }

      _variables.first[name] = value;
      if (_variableNodes != null) _variableNodes.first[name] = nodeWithSpan;
      return;
    }

    var index = _lastVariableName == name
        ? _lastVariableIndex
        : _variableIndices.putIfAbsent(
            name, () => _variableIndex(name) ?? _variables.length - 1);
    if (!_inSemiGlobalScope && index == 0) {
      index = _variables.length - 1;
      _variableIndices[name] = index;
    }

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variables[index][name] = value;
    if (_variableNodes != null) _variableNodes[index][name] = nodeWithSpan;
  }

  /// Sets the variable named [name] to [value], associated with
  /// [nodeWithSpan]'s source span.
  ///
  /// Unlike [setVariable], this will declare the variable in the current scope
  /// even if a declaration already exists in an outer scope.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  void setLocalVariable(String name, Value value, AstNode nodeWithSpan) {
    var index = _variables.length - 1;
    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    _variables[index][name] = value;
    if (_variableNodes != null) _variableNodes[index][name] = nodeWithSpan;
  }

  /// Returns the value of the function named [name], optionally with the given
  /// [namespace], or `null` if no such variable is declared.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose functions named [name].
  Callable getFunction(String name, {String namespace}) {
    if (namespace != null) return _getModule(namespace).functions[name];

    var index = _functionIndices[name];
    if (index != null) {
      return _functions[index][name] ?? _getFunctionFromGlobalModule(name);
    }

    index = _functionIndex(name);
    if (index == null) return _getFunctionFromGlobalModule(name);

    _functionIndices[name] = index;
    return _functions[index][name] ?? _getFunctionFromGlobalModule(name);
  }

  /// Returns the value of the function named [name] from a namespaceless
  /// module, or `null` if no such function is declared in any namespaceless
  /// module.
  Callable _getFunctionFromGlobalModule(String name) =>
      _fromOneModule("function", name, (module) => module.functions[name]);

  /// Returns the index of the last map in [_functions] that has a [name] key,
  /// or `null` if none exists.
  int _functionIndex(String name) {
    for (var i = _functions.length - 1; i >= 0; i--) {
      if (_functions[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Returns whether a function named [name] exists.
  bool functionExists(String name) => getFunction(name) != null;

  /// Sets the variable named [name] to [value] in the current scope.
  void setFunction(Callable callable) {
    var index = _functions.length - 1;
    _functionIndices[callable.name] = index;
    _functions[index][callable.name] = callable;
  }

  /// Returns the value of the mixin named [name], optionally with the given
  /// [namespace], or `null` if no such variable is declared.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose mixins named [name].
  Callable getMixin(String name, {String namespace}) {
    if (namespace != null) return _getModule(namespace).mixins[name];

    var index = _mixinIndices[name];
    if (index != null) {
      return _mixins[index][name] ?? _getMixinFromGlobalModule(name);
    }

    index = _mixinIndex(name);
    if (index == null) return _getMixinFromGlobalModule(name);

    _mixinIndices[name] = index;
    return _mixins[index][name] ?? _getMixinFromGlobalModule(name);
  }

  /// Returns the value of the mixin named [name] from a namespaceless
  /// module, or `null` if no such mixin is declared in any namespaceless
  /// module.
  Callable _getMixinFromGlobalModule(String name) =>
      _fromOneModule("mixin", name, (module) => module.mixins[name]);

  /// Returns the index of the last map in [_mixins] that has a [name] key, or
  /// `null` if none exists.
  int _mixinIndex(String name) {
    for (var i = _mixins.length - 1; i >= 0; i--) {
      if (_mixins[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Returns whether a mixin named [name] exists.
  bool mixinExists(String name) => getMixin(name) != null;

  /// Sets the variable named [name] to [value] in the current scope.
  void setMixin(Callable callable) {
    var index = _mixins.length - 1;
    _mixinIndices[callable.name] = index;
    _mixins[index][callable.name] = callable;
  }

  /// Sets [content] as [this.content] for the duration of [callback].
  void withContent(UserDefinedCallable<Environment> content, void callback()) {
    var oldContent = _content;
    _content = content;
    callback();
    _content = oldContent;
  }

  /// Sets [inMixin] to `true` for the duration of [callback].
  void asMixin(void callback()) {
    var oldInMixin = _inMixin;
    _inMixin = true;
    callback();
    _inMixin = oldInMixin;
  }

  /// Runs [callback] in a new scope.
  ///
  /// Variables, functions, and mixins declared in a given scope are
  /// inaccessible outside of it. If [semiGlobal] is passed, this scope can
  /// assign to global variables without a `!global` declaration.
  ///
  /// If [when] is false, this doesn't create a new scope and instead just
  /// executes [callback] and returns its result.
  T scope<T>(T callback(), {bool semiGlobal = false, bool when = true}) {
    if (!when) {
      // We still have to track semi-globalness so that
      //
      //     div {
      //       @if ... {
      //         $x: y;
      //       }
      //     }
      //
      // doesn't assign to the global scope.
      var wasInSemiGlobalScope = _inSemiGlobalScope;
      _inSemiGlobalScope = semiGlobal;
      try {
        return callback();
      } finally {
        _inSemiGlobalScope = wasInSemiGlobalScope;
      }
    }

    semiGlobal = semiGlobal && _inSemiGlobalScope;
    var wasInSemiGlobalScope = _inSemiGlobalScope;
    _inSemiGlobalScope = semiGlobal;

    _variables.add(normalizedMap());
    _variableNodes?.add(normalizedMap());
    _functions.add(normalizedMap());
    _mixins.add(normalizedMap());
    try {
      return callback();
    } finally {
      _inSemiGlobalScope = wasInSemiGlobalScope;
      _lastVariableName = null;
      _lastVariableIndex = null;
      for (var name in _variables.removeLast().keys) {
        _variableIndices.remove(name);
      }
      for (var name in _functions.removeLast().keys) {
        _functionIndices.remove(name);
      }
      for (var name in _mixins.removeLast().keys) {
        _mixinIndices.remove(name);
      }
    }
  }

  /// Returns a module that represents the top-level members defined in [this],
  /// that contains [css] as its CSS tree, which can be extended using
  /// [extender].
  Module toModule(CssStylesheet css, Extender extender) =>
      _EnvironmentModule(this, css, extender);

  /// Returns the module with the given [namespace], or throws a
  /// [SassScriptException] if none exists.
  Module _getModule(String namespace) {
    var module = _modules[namespace];
    if (module != null) return module;

    throw SassScriptException(
        'There is no module with the namespace "$namespace".');
  }

  /// Returns the result of [callback] if it returns non-`null` for exactly one
  /// module in [_globalModules].
  ///
  /// Returns `null` if [callback] returns `null` for all modules. Throws an
  /// error if [callback] returns non-`null` for more than one module.
  ///
  /// The [type] should be the singular name of the value type being returned.
  /// The [name] should be the specific name being looked up. These are's used
  /// to format an appropriate error message.
  T _fromOneModule<T>(String type, String name, T callback(Module module)) {
    if (_globalModules == null) return null;

    T value;
    for (var module in _globalModules) {
      var valueInModule = callback(module);
      if (valueInModule != null && value != null) {
        // TODO(nweiz): List the module URLs.
        throw SassScriptException(
            'Multiple global modules have a $type named "$name".');
      }

      value = valueInModule;
    }
    return value;
  }
}

/// A module that represents the top-level members defined in an [Environment].
class _EnvironmentModule implements Module {
  Uri get url => css.span.sourceUrl;

  final List<Module> upstream;
  final Map<String, Value> variables;
  final Map<String, AstNode> variableNodes;
  final Map<String, Callable> functions;
  final Map<String, Callable> mixins;
  final Extender extender;
  final CssStylesheet css;
  final bool transitivelyContainsCss;
  final bool transitivelyContainsExtensions;

  /// The environment that defines this module's members.
  final Environment _environment;

  // TODO(nweiz): Use custom [UnmodifiableMapView]s that forbid access to
  // private members.
  _EnvironmentModule(this._environment, this.css, this.extender)
      : upstream = _environment._allModules,
        variables = PublicMemberMap(_environment._variables.first),
        variableNodes = _environment._variableNodes == null
            ? null
            : PublicMemberMap(_environment._variableNodes.first),
        functions = PublicMemberMap(_environment._functions.first),
        mixins = PublicMemberMap(_environment._mixins.first),
        transitivelyContainsCss = css.children.isNotEmpty ||
            _environment._allModules
                .any((module) => module.transitivelyContainsCss),
        transitivelyContainsExtensions = !extender.isEmpty ||
            _environment._allModules
                .any((module) => module.transitivelyContainsExtensions);

  void setVariable(String name, Value value, AstNode nodeWithSpan) {
    if (!_environment._variables.first.containsKey(name)) {
      throw SassScriptException("Undefined variable.");
    }

    _environment._variables.first[name] = value;
    if (_environment._variableNodes != null) {
      _environment._variableNodes.first[name] = nodeWithSpan;
    }
    return;
  }

  Module cloneCss() {
    if (css.children.isEmpty) return this;

    var newCssAndExtender = cloneCssStylesheet(css, extender);
    return _EnvironmentModule(
        _environment, newCssAndExtender.item1, newCssAndExtender.item2);
  }

  String toString() => p.prettyUri(css.span.sourceUrl);
}
