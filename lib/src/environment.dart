// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'callable.dart';
import 'functions.dart';
import 'value.dart';
import 'utils.dart';

// Lexical environment only
class Environment {
  /// Base is global scope.
  final List<Map<String, Value>> _variables;

  // Note: this is not necessarily complete
  final Map<String, int> _variableIndices;

  final List<Map<String, Callable>> _functions;

  // Note: this is not necessarily complete
  final Map<String, int> _functionIndices;

  final List<Map<String, Callable>> _mixins;

  // Note: this is not necessarily complete
  final Map<String, int> _mixinIndices;

  /// The content block passed to the lexically-current mixin, if any.
  List<Statement> get contentBlock => _contentBlock;
  List<Statement> _contentBlock;

  /// The environment for [_contentBlock].
  Environment get contentEnvironment => _contentEnvironment;
  Environment _contentEnvironment;

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

  Environment._(
      this._variables,
      this._variableIndices,
      this._functions,
      this._functionIndices,
      this._mixins,
      this._mixinIndices,
      this._contentBlock,
      this._contentEnvironment);

  Environment closure() => new Environment._(
      _variables.toList(),
      new Map.from(_variableIndices),
      _functions.toList(),
      new Map.from(_functionIndices),
      _mixins.toList(),
      new Map.from(_mixinIndices),
      _contentBlock,
      _contentEnvironment);

  Environment global() => new Environment._([_variables.first], {},
      [_functions.first], {}, [_mixins.first], {}, null, null);

  Value getVariable(String name) {
    var index = _variableIndices[name];
    if (index != null) _variables[index][name];

    index = _variableIndex(name);
    if (index == null) return null;

    _variableIndices[name] = index;
    return _variables[index][name];
  }

  bool variableExists(String name) => getVariable(name) != null;

  bool globalVariableExists(String name) => _variables.first.containsKey(name);

  int _variableIndex(String name) {
    for (var i = _variables.length - 1; i >= 0; i--) {
      if (_variables[i].containsKey(name)) return i;
    }
    return null;
  }

  void setVariable(String name, Value value, {bool global: false}) {
    var index = global || _variables.length == 1
        ? 0
        : _variableIndices.putIfAbsent(
            name, () => _inSemiGlobalScope ? 0 : _variables.length - 1);
    _variables[index][name] = value;
  }

  void setLocalVariable(String name, Value value) {
    var index = _variables.length - 1;
    _variableIndices[name] = index;
    _variables[index][name] = value;
  }

  Callable getFunction(String name) {
    var index = _functionIndices[name];
    if (index != null) _functions[index][name];

    index = _functionIndex(name);
    if (index == null) return null;

    _functionIndices[name] = index;
    return _functions[index][name];
  }

  int _functionIndex(String name) {
    for (var i = _functions.length - 1; i >= 0; i--) {
      if (_functions[i].containsKey(name)) return i;
    }
    return null;
  }

  void setFunction(Callable callable) {
    _functions[_functions.length - 1][callable.name] = callable;
  }

  void defineFunction(String name, String arguments,
          Value callback(List<Value> arguments)) =>
      setFunction(new BuiltInCallable(name, arguments, callback));

  Callable getMixin(String name) {
    var index = _mixinIndices[name];
    if (index != null) _mixins[index][name];

    index = _mixinIndex(name);
    if (index == null) return null;

    _mixinIndices[name] = index;
    return _mixins[index][name];
  }

  int _mixinIndex(String name) {
    for (var i = _mixins.length - 1; i >= 0; i--) {
      if (_mixins[i].containsKey(name)) return i;
    }
    return null;
  }

  void setMixin(Callable callable) {
    _mixins[_mixins.length - 1][callable.name] = callable;
  }

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
