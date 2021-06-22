// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_environment.dart.
// See tool/grind/synchronize.dart for details.
//
// Checksum: 6e5ee671e0a6e5b1d6ac87beb6aeee1e4b155d74
//
// ignore_for_file: unused_import

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'ast/css.dart';
import 'ast/node.dart';
import 'ast/sass.dart';
import 'callable.dart';
import 'configuration.dart';
import 'configured_value.dart';
import 'exception.dart';
import 'extend/extension_store.dart';
import 'module.dart';
import 'module/forwarded_view.dart';
import 'module/shadowed_view.dart';
import 'util/merged_map_view.dart';
import 'util/nullable.dart';
import 'util/public_member_map_view.dart';
import 'utils.dart';
import 'value.dart';
import 'visitor/clone_css.dart';

// TODO(nweiz): This used to avoid tracking source spans for variables if source
// map generation was disabled. We always have to track them now to produce
// better warnings for /-as-division, but once those warnings are gone we should
// go back to tracking conditionally.

/// The lexical environment in which Sass is executed.
///
/// This tracks lexically-scoped information, such as variables, functions, and
/// mixins.
class Environment {
  /// The modules used in the current scope, indexed by their namespaces.
  Map<String, Module<Callable>> get modules => UnmodifiableMapView(_modules);
  final Map<String, Module<Callable>> _modules;

  /// A map from module namespaces to the nodes whose spans indicate where those
  /// modules were originally loaded.
  final Map<String, AstNode> _namespaceNodes;

  /// A map from namespaceless modules to the `@use` rules whose spans indicate
  /// where those modules were originally loaded.
  ///
  /// This does not include modules that were imported into the current scope.
  final Map<Module<Callable>, AstNode> _globalModules;

  /// A map from modules that were imported into the current scope to the nodes
  /// whose spans indicate where those modules were originally loaded.
  final Map<Module<Callable>, AstNode> _importedModules;

  /// A map from modules forwarded by this module to the nodes whose spans
  /// indicate where those modules were originally forwarded.
  ///
  /// This is `null` if there are no forwarded modules.
  Map<Module<Callable>, AstNode>? _forwardedModules;

  /// Modules forwarded by nested imports at each lexical scope level *beneath
  /// the global scope*.
  ///
  /// This is `null` until it's needed, since most environments won't ever use
  /// this.
  List<List<Module<Callable>>>? _nestedForwardedModules;

  /// Modules from [_modules], [_globalModules], and [_forwardedModules], in the
  /// order in which they were `@use`d.
  final List<Module<Callable>> _allModules;

  /// A list of variables defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared variables to their values.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Value>> _variables;

  /// The nodes where each variable in [_variables] was defined.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  final List<Map<String, AstNode>> _variableNodes;

  /// A map of variable names to their indices in [_variables].
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _variableIndices;

  /// A list of functions defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared functions to their values.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Callable>> _functions;

  /// A map of function names to their indices in [_functions].
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _functionIndices;

  /// A list of mixins defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared mixins to their values.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Callable>> _mixins;

  /// A map of mixin names to their indices in [_mixins].
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _mixinIndices;

  /// The content block passed to the lexically-enclosing mixin, or `null` if
  /// this is not in a mixin, or if no content block was passed.
  UserDefinedCallable<Environment>? get content => _content;
  UserDefinedCallable<Environment>? _content;

  /// Whether the environment is lexically at the root of the document.
  bool get atRoot => _variables.length == 1;

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
  String? _lastVariableName;

  /// The index in [_variables] of the last variable that was accessed.
  int? _lastVariableIndex;

  /// Creates an [Environment].
  ///
  /// If [sourceMap] is `true`, this tracks variables' source locations
  Environment()
      : _modules = {},
        _namespaceNodes = {},
        _globalModules = {},
        _importedModules = {},
        _forwardedModules = null,
        _nestedForwardedModules = null,
        _allModules = [],
        _variables = [{}],
        _variableNodes = [{}],
        _variableIndices = {},
        _functions = [{}],
        _functionIndices = {},
        _mixins = [{}],
        _mixinIndices = {};

  Environment._(
      this._modules,
      this._namespaceNodes,
      this._globalModules,
      this._importedModules,
      this._forwardedModules,
      this._nestedForwardedModules,
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
      : _variableIndices = {},
        _functionIndices = {},
        _mixinIndices = {};

  /// Creates a closure based on this environment.
  ///
  /// Any scope changes in this environment will not affect the closure.
  /// However, any new declarations or assignments in scopes that are visible
  /// when the closure was created will be reflected.
  Environment closure() => Environment._(
      _modules,
      _namespaceNodes,
      _globalModules,
      _importedModules,
      _forwardedModules,
      _nestedForwardedModules,
      _allModules,
      _variables.toList(),
      _variableNodes.toList(),
      _functions.toList(),
      _mixins.toList(),
      _content);

  /// Returns a new environment to use for an imported file.
  ///
  /// The returned environment shares this environment's variables, functions,
  /// and mixins, but excludes most modules (except for global modules that
  /// result from importing a file with forwards).
  Environment forImport() => Environment._(
      {},
      {},
      {},
      _importedModules,
      null,
      null,
      [],
      _variables.toList(),
      _variableNodes.toList(),
      _functions.toList(),
      _mixins.toList(),
      _content);

  /// Adds [module] to the set of modules visible in this environment.
  ///
  /// [nodeWithSpan]'s span is used to report any errors with the module.
  ///
  /// If [namespace] is passed, the module is made available under that
  /// namespace.
  ///
  /// Throws a [SassScriptException] if there's already a module with the given
  /// [namespace], or if [namespace] is `null` and [module] defines a variable
  /// with the same name as a variable defined in this environment.
  void addModule(Module<Callable> module, AstNode nodeWithSpan,
      {String? namespace}) {
    if (namespace == null) {
      _globalModules[module] = nodeWithSpan;
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
        var span = _namespaceNodes[namespace]?.span;
        throw MultiSpanSassScriptException(
            "There's already a module with namespace \"$namespace\".",
            "new @use",
            {if (span != null) span: "original @use"});
      }

      _modules[namespace] = module;
      _namespaceNodes[namespace] = nodeWithSpan;
      _allModules.add(module);
    }
  }

  /// Exposes the members in [module] to downstream modules as though they were
  /// defined in this module, according to the modifications defined by [rule].
  void forwardModule(Module<Callable> module, ForwardRule rule) {
    var forwardedModules = (_forwardedModules ??= {});

    var view = ForwardedModuleView.ifNecessary(module, rule);
    for (var other in forwardedModules.keys) {
      _assertNoConflicts(
          view.variables, other.variables, view, other, "variable");
      _assertNoConflicts(
          view.functions, other.functions, view, other, "function");
      _assertNoConflicts(view.mixins, other.mixins, view, other, "mixin");
    }

    // Add the original module to [_allModules] (rather than the
    // [ForwardedModuleView]) so that we can de-duplicate upstream modules using
    // `==`. This is safe because upstream modules are only used for collating
    // CSS, not for the members they expose.
    _allModules.add(module);
    forwardedModules[view] = rule;
  }

  /// Throws a [SassScriptException] if [newMembers] from [newModule] has any
  /// keys that overlap with [oldMembers] from [oldModule].
  ///
  /// The [type] and [newModuleNodeWithSpan] are used for error reporting.
  void _assertNoConflicts(
      Map<String, Object> newMembers,
      Map<String, Object> oldMembers,
      Module<Callable> newModule,
      Module<Callable> oldModule,
      String type) {
    Map<String, Object> smaller;
    Map<String, Object> larger;
    if (newMembers.length < oldMembers.length) {
      smaller = newMembers;
      larger = oldMembers;
    } else {
      smaller = oldMembers;
      larger = newMembers;
    }

    for (var name in smaller.keys) {
      if (!larger.containsKey(name)) continue;
      if (type == "variable"
          ? newModule.variableIdentity(name) == oldModule.variableIdentity(name)
          : larger[name] == smaller[name]) {
        continue;
      }

      if (type == "variable") name = "\$$name";
      var span = _forwardedModules?[oldModule]?.span;
      throw MultiSpanSassScriptException(
          'Two forwarded modules both define a $type named $name.',
          "new @forward",
          {if (span != null) span: "original @forward"});
    }
  }

  /// Makes the members forwarded by [module] available in the current
  /// environment.
  ///
  /// This is called when [module] is `@import`ed.
  void importForwards(Module<Callable> module) {
    if (module is _EnvironmentModule) {
      var forwarded = module._environment._forwardedModules;
      if (forwarded == null) return;

      // Omit modules from [forwarded] that are already globally available and
      // forwarded in this module.
      var forwardedModules = _forwardedModules;
      if (forwardedModules != null) {
        forwarded = {
          for (var entry in forwarded.entries)
            if (!forwardedModules.containsKey(entry.key) ||
                !_globalModules.containsKey(entry.key))
              entry.key: entry.value,
        };
      } else {
        forwardedModules = _forwardedModules ??= {};
      }

      var forwardedVariableNames =
          forwarded.keys.expand((module) => module.variables.keys).toSet();
      var forwardedFunctionNames =
          forwarded.keys.expand((module) => module.functions.keys).toSet();
      var forwardedMixinNames =
          forwarded.keys.expand((module) => module.mixins.keys).toSet();

      if (atRoot) {
        // Hide members from modules that have already been imported or
        // forwarded that would otherwise conflict with the @imported members.
        for (var entry in _importedModules.entries.toList()) {
          var module = entry.key;
          var shadowed = ShadowedModuleView.ifNecessary(module,
              variables: forwardedVariableNames,
              mixins: forwardedMixinNames,
              functions: forwardedFunctionNames);
          if (shadowed != null) {
            _importedModules.remove(module);
            if (!shadowed.isEmpty) _importedModules[shadowed] = entry.value;
          }
        }

        for (var entry in forwardedModules.entries.toList()) {
          var module = entry.key;
          var shadowed = ShadowedModuleView.ifNecessary(module,
              variables: forwardedVariableNames,
              mixins: forwardedMixinNames,
              functions: forwardedFunctionNames);
          if (shadowed != null) {
            forwardedModules.remove(module);
            if (!shadowed.isEmpty) forwardedModules[shadowed] = entry.value;
          }
        }

        _importedModules.addAll(forwarded);
        forwardedModules.addAll(forwarded);
      } else {
        (_nestedForwardedModules ??=
                List.generate(_variables.length - 1, (_) => []))
            .last
            .addAll(forwarded.keys);
      }

      // Remove existing member definitions that are now shadowed by the
      // forwarded modules.
      for (var variable in forwardedVariableNames) {
        _variableIndices.remove(variable);
        _variables.last.remove(variable);
        _variableNodes.last.remove(variable);
      }
      for (var function in forwardedFunctionNames) {
        _functionIndices.remove(function);
        _functions.last.remove(function);
      }
      for (var mixin in forwardedMixinNames) {
        _mixinIndices.remove(mixin);
        _mixins.last.remove(mixin);
      }
    }
  }

  /// Returns the value of the variable named [name], optionally with the given
  /// [namespace], or `null` if no such variable is declared.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose variables named [name].
  Value? getVariable(String name, {String? namespace}) {
    if (namespace != null) return _getModule(namespace).variables[name];

    if (_lastVariableName == name) {
      return _variables[_lastVariableIndex!][name] ??
          _getVariableFromGlobalModule(name);
    }

    var index = _variableIndices[name];
    if (index != null) {
      _lastVariableName = name;
      _lastVariableIndex = index;
      return _variables[index][name] ?? _getVariableFromGlobalModule(name);
    }

    index = _variableIndex(name);
    if (index == null) {
      // There isn't a real variable defined as this index, but it will cause
      // [getVariable] to short-circuit and get to this function faster next
      // time the variable is accessed.
      return _getVariableFromGlobalModule(name);
    }

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    return _variables[index][name] ?? _getVariableFromGlobalModule(name);
  }

  /// Returns the value of the variable named [name] from a namespaceless
  /// module, or `null` if no such variable is declared in any namespaceless
  /// module.
  Value? _getVariableFromGlobalModule(String name) =>
      _fromOneModule(name, "variable", (module) => module.variables[name]);

  /// Returns the node for the variable named [name], or `null` if no such
  /// variable is declared.
  ///
  /// This node is intended as a proxy for the [FileSpan] indicating where the
  /// variable's value originated. It's returned as an [AstNode] rather than a
  /// [FileSpan] so we can avoid calling [AstNode.span] if the span isn't
  /// required, since some nodes need to do real work to manufacture a source
  /// span.
  AstNode? getVariableNode(String name, {String? namespace}) {
    if (namespace != null) return _getModule(namespace).variableNodes[name];

    if (_lastVariableName == name) {
      return _variableNodes[_lastVariableIndex!][name] ??
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
  AstNode? _getVariableNodeFromGlobalModule(String name) {
    // We don't need to worry about multiple modules defining the same variable,
    // because that's already been checked by [getVariable].
    for (var module in _importedModules.keys.followedBy(_globalModules.keys)) {
      var value = module.variableNodes[name];
      if (value != null) return value;
    }
    return null;
  }

  /// Returns whether a variable named [name] exists.
  bool variableExists(String name) => getVariable(name) != null;

  /// Returns whether a global variable named [name] exists.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose functions named [name].
  bool globalVariableExists(String name, {String? namespace}) {
    if (namespace != null) {
      return _getModule(namespace).variables.containsKey(name);
    }
    if (_variables.first.containsKey(name)) return true;
    return _getVariableFromGlobalModule(name) != null;
  }

  /// Returns the index of the last map in [_variables] that has a [name] key,
  /// or `null` if none exists.
  int? _variableIndex(String name) {
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
      {String? namespace, bool global = false}) {
    if (namespace != null) {
      _getModule(namespace).setVariable(name, value, nodeWithSpan);
      return;
    }

    if (global || atRoot) {
      // Don't set the index if there's already a variable with the given name,
      // since local accesses should still return the local variable.
      _variableIndices.putIfAbsent(name, () {
        _lastVariableName = name;
        _lastVariableIndex = 0;
        return 0;
      });

      // If this module doesn't already contain a variable named [name], try
      // setting it in a global module.
      if (!_variables.first.containsKey(name)) {
        var moduleWithName = _fromOneModule(name, "variable",
            (module) => module.variables.containsKey(name) ? module : null);
        if (moduleWithName != null) {
          moduleWithName.setVariable(name, value, nodeWithSpan);
          return;
        }
      }

      _variables.first[name] = value;
      _variableNodes.first[name] = nodeWithSpan;
      return;
    }

    var nestedForwardedModules = _nestedForwardedModules;
    if (nestedForwardedModules != null &&
        !_variableIndices.containsKey(name) &&
        _variableIndex(name) == null) {
      for (var modules in nestedForwardedModules.reversed) {
        for (var module in modules.reversed) {
          if (module.variables.containsKey(name)) {
            module.setVariable(name, value, nodeWithSpan);
            return;
          }
        }
      }
    }

    var index = _lastVariableName == name
        ? _lastVariableIndex!
        : _variableIndices.putIfAbsent(
            name, () => _variableIndex(name) ?? _variables.length - 1);
    if (!_inSemiGlobalScope && index == 0) {
      index = _variables.length - 1;
      _variableIndices[name] = index;
    }

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variables[index][name] = value;
    _variableNodes[index][name] = nodeWithSpan;
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
    _variableNodes[index][name] = nodeWithSpan;
  }

  /// Returns the value of the function named [name], optionally with the given
  /// [namespace], or `null` if no such variable is declared.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose functions named [name].
  Callable? getFunction(String name, {String? namespace}) {
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
  Callable? _getFunctionFromGlobalModule(String name) =>
      _fromOneModule(name, "function", (module) => module.functions[name]);

  /// Returns the index of the last map in [_functions] that has a [name] key,
  /// or `null` if none exists.
  int? _functionIndex(String name) {
    for (var i = _functions.length - 1; i >= 0; i--) {
      if (_functions[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Returns whether a function named [name] exists.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose functions named [name].
  bool functionExists(String name, {String? namespace}) =>
      getFunction(name, namespace: namespace) != null;

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
  Callable? getMixin(String name, {String? namespace}) {
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
  Callable? _getMixinFromGlobalModule(String name) =>
      _fromOneModule(name, "mixin", (module) => module.mixins[name]);

  /// Returns the index of the last map in [_mixins] that has a [name] key, or
  /// `null` if none exists.
  int? _mixinIndex(String name) {
    for (var i = _mixins.length - 1; i >= 0; i--) {
      if (_mixins[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Returns whether a mixin named [name] exists.
  ///
  /// Throws a [SassScriptException] if there is no module named [namespace], or
  /// if multiple global modules expose functions named [name].
  bool mixinExists(String name, {String? namespace}) =>
      getMixin(name, namespace: namespace) != null;

  /// Sets the variable named [name] to [value] in the current scope.
  void setMixin(Callable callable) {
    var index = _mixins.length - 1;
    _mixinIndices[callable.name] = index;
    _mixins[index][callable.name] = callable;
  }

  /// Sets [content] as [this.content] for the duration of [callback].
  void withContent(UserDefinedCallable<Environment>? content, void callback()) {
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
    // We have to track semi-globalness even if `!when` so that
    //
    //     div {
    //       @if ... {
    //         $x: y;
    //       }
    //     }
    //
    // doesn't assign to the global scope.
    semiGlobal = semiGlobal && _inSemiGlobalScope;
    var wasInSemiGlobalScope = _inSemiGlobalScope;
    _inSemiGlobalScope = semiGlobal;

    if (!when) {
      try {
        return callback();
      } finally {
        _inSemiGlobalScope = wasInSemiGlobalScope;
      }
    }

    _variables.add({});
    _variableNodes.add({});
    _functions.add({});
    _mixins.add({});
    _nestedForwardedModules?.add([]);
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
      _nestedForwardedModules?.removeLast();
    }
  }

  /// Creates an implicit configuration from the variables declared in this
  /// environment.
  Configuration toImplicitConfiguration() {
    var configuration = <String, ConfiguredValue>{};
    for (var i = 0; i < _variables.length; i++) {
      var values = _variables[i];
      var nodes = _variableNodes[i];
      for (var entry in values.entries) {
        // Implicit configurations are never invalid, making [configurationSpan]
        // unnecessary, so we pass null here to avoid having to compute it.
        configuration[entry.key] =
            ConfiguredValue.implicit(entry.value, nodes[entry.key]!);
      }
    }
    return Configuration.implicit(configuration);
  }

  /// Returns a module that represents the top-level members defined in [this],
  /// that contains [css] as its CSS tree, which can be extended using
  /// [extensionStore].
  Module<Callable> toModule(CssStylesheet css, ExtensionStore extensionStore) {
    assert(atRoot);
    return _EnvironmentModule(this, css, extensionStore,
        forwarded: _forwardedModules.andThen((modules) => MapKeySet(modules)));
  }

  /// Returns a module with the same members and upstream modules as [this], but
  /// an empty stylesheet and extension store.
  ///
  /// This is used when resolving imports, since they need to inject forwarded
  /// members into the current scope. It's the only situation in which a nested
  /// environment can become a module.
  Module<Callable> toDummyModule() {
    return _EnvironmentModule(
        this,
        CssStylesheet(const [],
            SourceFile.decoded(const [], url: "<dummy module>").span(0)),
        ExtensionStore.empty,
        forwarded: _forwardedModules.andThen((modules) => MapKeySet(modules)));
  }

  /// Returns the module with the given [namespace], or throws a
  /// [SassScriptException] if none exists.
  Module<Callable> _getModule(String namespace) {
    var module = _modules[namespace];
    if (module != null) return module;

    throw SassScriptException(
        'There is no module with the namespace "$namespace".');
  }

  /// Returns the result of [callback] if it returns non-`null` for exactly one
  /// module in [_globalModules] *or* for any module in [_importedModules] or
  /// [_nestedForwardedModules].
  ///
  /// Returns `null` if [callback] returns `null` for all modules. Throws an
  /// error if [callback] returns non-`null` for more than one module.
  ///
  /// The [name] is the name of the member being looked up.
  ///
  /// The [type] should be the singular name of the value type being returned.
  /// It's used to format an appropriate error message.
  T? _fromOneModule<T>(
      String name, String type, T? callback(Module<Callable> module)) {
    var nestedForwardedModules = _nestedForwardedModules;
    if (nestedForwardedModules != null) {
      for (var modules in nestedForwardedModules.reversed) {
        for (var module in modules.reversed) {
          var value = callback(module);
          if (value != null) return value;
        }
      }
    }
    for (var module in _importedModules.keys) {
      var value = callback(module);
      if (value != null) return value;
    }

    T? value;
    Object? identity;
    for (var module in _globalModules.keys) {
      var valueInModule = callback(module);
      if (valueInModule == null) continue;

      Object? identityFromModule = valueInModule is Callable
          ? valueInModule
          : module.variableIdentity(name);
      if (identityFromModule == identity) continue;

      if (value != null) {
        var spans = _globalModules.entries.map(
            (entry) => callback(entry.key).andThen((_) => entry.value.span));

        throw MultiSpanSassScriptException(
            'This $type is available from multiple global modules.',
            '$type use', {
          for (var span in spans)
            if (span != null) span: 'includes $type'
        });
      }

      value = valueInModule;
      identity = identityFromModule;
    }
    return value;
  }
}

/// A module that represents the top-level members defined in an [Environment].
class _EnvironmentModule implements Module<Callable> {
  Uri? get url => css.span.sourceUrl;

  final List<Module<Callable>> upstream;
  final Map<String, Value> variables;
  final Map<String, AstNode> variableNodes;
  final Map<String, Callable> functions;
  final Map<String, Callable> mixins;
  final ExtensionStore extensionStore;
  final CssStylesheet css;
  final bool transitivelyContainsCss;
  final bool transitivelyContainsExtensions;

  /// The environment that defines this module's members.
  final Environment _environment;

  /// A map from variable names to the modules in which those variables appear,
  /// used to determine where variables should be set.
  ///
  /// Variables that don't appear in this map are either defined directly in
  /// this module (if they appear in `_environment._variables.first`) or not
  /// defined at all.
  final Map<String, Module<Callable>> _modulesByVariable;

  factory _EnvironmentModule(
      Environment environment, CssStylesheet css, ExtensionStore extensionStore,
      {Set<Module<Callable>>? forwarded}) {
    forwarded ??= const {};
    return _EnvironmentModule._(
        environment,
        css,
        extensionStore,
        _makeModulesByVariable(forwarded),
        _memberMap(environment._variables.first,
            forwarded.map((module) => module.variables)),
        _memberMap(environment._variableNodes.first,
            forwarded.map((module) => module.variableNodes)),
        _memberMap(environment._functions.first,
            forwarded.map((module) => module.functions)),
        _memberMap(environment._mixins.first,
            forwarded.map((module) => module.mixins)),
        transitivelyContainsCss: css.children.isNotEmpty ||
            environment._allModules
                .any((module) => module.transitivelyContainsCss),
        transitivelyContainsExtensions: !extensionStore.isEmpty ||
            environment._allModules
                .any((module) => module.transitivelyContainsExtensions));
  }

  /// Create [_modulesByVariable] for a set of forwarded modules.
  static Map<String, Module<Callable>> _makeModulesByVariable(
      Set<Module<Callable>> forwarded) {
    if (forwarded.isEmpty) return const {};

    var modulesByVariable = <String, Module<Callable>>{};
    for (var module in forwarded) {
      if (module is _EnvironmentModule) {
        // Flatten nested forwarded modules to avoid O(depth) overhead.
        for (var child in module._modulesByVariable.values) {
          setAll(modulesByVariable, child.variables.keys, child);
        }
        setAll(modulesByVariable, module._environment._variables.first.keys,
            module);
      } else {
        setAll(modulesByVariable, module.variables.keys, module);
      }
    }
    return modulesByVariable;
  }

  /// Returns a map that exposes the public members of [localMap] as well as all
  /// the members of [otherMaps].
  static Map<String, V> _memberMap<V>(
      Map<String, V> localMap, Iterable<Map<String, V>> otherMaps) {
    localMap = PublicMemberMapView(localMap);
    if (otherMaps.isEmpty) return localMap;

    var allMaps = [
      for (var map in otherMaps)
        if (map.isNotEmpty) map,
      localMap
    ];
    if (allMaps.length == 1) return localMap;

    return MergedMapView(allMaps);
  }

  _EnvironmentModule._(
      this._environment,
      this.css,
      this.extensionStore,
      this._modulesByVariable,
      this.variables,
      this.variableNodes,
      this.functions,
      this.mixins,
      {required this.transitivelyContainsCss,
      required this.transitivelyContainsExtensions})
      : upstream = _environment._allModules;

  void setVariable(String name, Value value, AstNode nodeWithSpan) {
    var module = _modulesByVariable[name];
    if (module != null) {
      module.setVariable(name, value, nodeWithSpan);
      return;
    }

    if (!_environment._variables.first.containsKey(name)) {
      throw SassScriptException("Undefined variable.");
    }

    _environment._variables.first[name] = value;
    _environment._variableNodes.first[name] = nodeWithSpan;
    return;
  }

  Object variableIdentity(String name) {
    assert(variables.containsKey(name));
    var module = _modulesByVariable[name];
    return module == null ? this : module.variableIdentity(name);
  }

  Module<Callable> cloneCss() {
    if (css.children.isEmpty) return this;

    var newCssAndExtensionStore = cloneCssStylesheet(css, extensionStore);
    return _EnvironmentModule._(
        _environment,
        newCssAndExtensionStore.item1,
        newCssAndExtensionStore.item2,
        _modulesByVariable,
        variables,
        variableNodes,
        functions,
        mixins,
        transitivelyContainsCss: transitivelyContainsCss,
        transitivelyContainsExtensions: transitivelyContainsExtensions);
  }

  String toString() => url == null ? "<unknown url>" : p.prettyUri(url);
}
