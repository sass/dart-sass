// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'callable.dart';
import 'functions.dart';
import 'value.dart';
import 'utils.dart';

// Lexical environment only
class Environment {
  /// Base is global scope.
  final List<Map<String, Value>> _variables;

  final Map<String, int> _variableIndices;

  final List<Map<String, Callable>> _functions;

  final Map<String, int> _functionIndices;

  final List<Map<String, Callable>> _mixins;

  final Map<String, int> _mixinIndices;

  Environment()
      : _variables = [normalizedMap()],
        _variableIndices = normalizedMap(),
        _functions = [normalizedMap()],
        _functionIndices = normalizedMap(),
        _mixins = [normalizedMap()],
        _mixinIndices = normalizedMap() {
    defineCoreFunctions(this);
  }

  Environment._(this._variables, this._variableIndices, this._functions,
      this._functionIndices, this._mixins, this._mixinIndices);

  Environment closure() => new Environment._(
      _variables.toList(),
      new Map.from(_variableIndices),
      _functions.toList(),
      new Map.from(_functionIndices),
      _mixins.toList(),
      new Map.from(_mixinIndices));

  Value getVariable(String name) =>
      _variables[_variableIndices[name] ?? 0][name];

  void setVariable(String name, Value value, {bool global: false}) {
    var index = global || _variables.length == 1
        ? 0
        : _variableIndices.putIfAbsent(name, () => _variables.length - 1);
    _variables[index][name] = value;
  }

  Callable getFunction(String name) =>
      _functions[_functionIndices[name] ?? 0][name];

  void setFunction(Callable callable) {
    var index = _functions.length == 1
        ? 0
        : _functionIndices.putIfAbsent(
              callable.name, () => _functions.length - 1);
    _functions[index][callable.name] = callable;
  }

  Callable getMixin(String name) =>
      _mixins[_mixinIndices[name] ?? 0][name];

  void setMixin(Callable callable) {
    var index = _mixins.length == 1
        ? 0
        : _mixinIndices.putIfAbsent(callable.name, () => _mixins.length - 1);
    _mixins[index][callable.name] = callable;
  }

  /*=T*/ scope/*<T>*/(/*=T*/ callback()) {
    // TODO: avoid creating a new scope if no variables are declared.
    _variables.add(normalizedMap());
    _functions.add(normalizedMap());
    _mixins.add(normalizedMap());
    try {
      return callback();
    } finally {
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
