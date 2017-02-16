// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'callable.dart';
import 'functions.dart';
import 'value.dart';
import 'utils.dart';

/// The lexical environment in which Sass is executed.
///
/// This tracks lexically-scoped information, such as variables, functions, and
/// mixins.
class Environment {
  /// A list of variables defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared variables to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Value>> _variables;

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

  /// The content block passed to the lexically-enclosing mixin, or `null` if this is not
  /// in a mixin, or if no content block was passed.
  List<Statement> get contentBlock => _contentBlock;
  List<Statement> _contentBlock;

  /// The environment in which [_contentBlock] should be executed.
  Environment get contentEnvironment => _contentEnvironment;
  Environment _contentEnvironment;

  /// Whether the environment is lexically within a mixin.
  bool get inMixin => _inMixin;
  var _inMixin = false;

  /// Whether the environment is currently in a semi-global scope.
  ///
  /// A semi-global scope can assign to global variables, but it doesn't declare
  /// them by default.
  var _inSemiGlobalScope = false;

  Environment()
      : _variables = [normalizedMap()],
        _variableIndices = normalizedMap(),
        _functions = [normalizedMap()],
        _functionIndices = normalizedMap(),
        _mixins = [normalizedMap()],
        _mixinIndices = normalizedMap() {
    defineCoreFunctions(this);
  }

  Environment._(this._variables, this._functions, this._mixins,
      this._contentBlock, this._contentEnvironment)
      // Lazily fill in the indices rather than eagerly copying them from the
      // existing environment in closure() and global() because the copying took a
      // lot of time and was rarely helpful. This saves a bunch of time on Susy's
      // tests.
      : _variableIndices = normalizedMap(),
        _functionIndices = normalizedMap(),
        _mixinIndices = normalizedMap();

  /// Creates a closure based on this environment.
  ///
  /// Any scope changes in this environment will not affect the closure.
  /// However, any new declarations or assignments in scopes that are visible
  /// when the closure was created will be reflected.
  Environment closure() => new Environment._(
      _variables.toList(),
      _functions.toList(),
      _mixins.toList(),
      _contentBlock,
      _contentEnvironment);

  /// Returns a new environment.
  ///
  /// The returned environment shares this environment's global, but is
  /// otherwise independent.
  Environment global() => new Environment._(
      [_variables.first], [_functions.first], [_mixins.first], null, null);

  /// Returns the value of the variable named [name], or `null` if no such
  /// variable is declared.
  Value getVariable(String name) {
    var index = _variableIndices[name];
    if (index != null) return _variables[index][name];

    index = _variableIndex(name);
    if (index == null) return null;

    _variableIndices[name] = index;
    return _variables[index][name];
  }

  /// Returns whether a variable named [name] exists.
  bool variableExists(String name) => getVariable(name) != null;

  /// Returns whether a global variable named [name] exists.
  bool globalVariableExists(String name) => _variables.first.containsKey(name);

  /// Returns the index of the last map in [_variables] that has a [name] key,
  /// or `null` if none exists.
  int _variableIndex(String name) {
    for (var i = _variables.length - 1; i >= 0; i--) {
      if (_variables[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Sets the variable named [name] to [value].
  ///
  /// If [global] is `true`, this sets the variable at the top-level scope.
  /// Otherwise, if the variable was already defined, it'll set it in the
  /// previous scope. If it's undefined, it'll set it in the current scope.
  void setVariable(String name, Value value, {bool global: false}) {
    if (global || _variables.length == 1) {
      // Don't set the index if there's already a variable with the given name,
      // since local accesses should still return the local variable.
      _variableIndices.putIfAbsent(name, () => 0);
      _variables.first[name] = value;
      return;
    }

    var index = _variableIndices.putIfAbsent(
        name, () => _variableIndex(name) ?? _variables.length - 1);
    if (!_inSemiGlobalScope && index == 0) {
      index = _variables.length - 1;
      _variableIndices[name] = index;
    }

    _variables[index][name] = value;
  }

  /// Sets the variable named [name] to [value] in the current scope.
  ///
  /// Unlike [setVariable], this will declare the variable in the current scope
  /// even if a declaration already exists in an outer scope.
  void setLocalVariable(String name, Value value) {
    var index = _variables.length - 1;
    _variableIndices[name] = index;
    _variables[index][name] = value;
  }

  /// Returns the value of the function named [name], or `null` if no such
  /// function is declared.
  Callable getFunction(String name) {
    var index = _functionIndices[name];
    if (index != null) return _functions[index][name];

    index = _functionIndex(name);
    if (index == null) return null;

    _functionIndices[name] = index;
    return _functions[index][name];
  }

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

  /// Shorthand for passing [new BuiltInCallable] to [setFunction].
  void defineFunction(String name, String arguments,
          Value callback(List<Value> arguments)) =>
      setFunction(new BuiltInCallable(name, arguments, callback));

  /// Returns the value of the mixin named [name], or `null` if no such mixin is
  /// declared.
  Callable getMixin(String name) {
    var index = _mixinIndices[name];
    if (index != null) return _mixins[index][name];

    index = _mixinIndex(name);
    if (index == null) return null;

    _mixinIndices[name] = index;
    return _mixins[index][name];
  }

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

  /// Sets [block] and [environment] as [contentBlock] and [contentEnvironment],
  /// respectively, for the duration of [callback].
  void withContent(
      List<Statement> block, Environment environment, void callback()) {
    var oldBlock = _contentBlock;
    var oldEnvironment = _contentEnvironment;
    _contentBlock = block;
    _contentEnvironment = environment;
    callback();
    _contentBlock = oldBlock;
    _contentEnvironment = oldEnvironment;
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
  /*=T*/ scope/*<T>*/(/*=T*/ callback(), {bool semiGlobal: false}) {
    semiGlobal = semiGlobal && (_inSemiGlobalScope || _variables.length == 1);

    // TODO: avoid creating a new scope if no variables are declared.
    var wasInSemiGlobalScope = _inSemiGlobalScope;
    _inSemiGlobalScope = semiGlobal;
    _variables.add(normalizedMap());
    _functions.add(normalizedMap());
    _mixins.add(normalizedMap());
    try {
      return callback();
    } finally {
      _inSemiGlobalScope = wasInSemiGlobalScope;
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
}
