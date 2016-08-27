// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'callable.dart';
import 'value.dart';
import 'utils.dart';

// Lexical environment only
class Environment {
  /// Base is global scope.
  final List<Map<String, Value>> _variables;

  final Map<String, int> _variableIndices;

  final List<Map<String, Callable>> _functions;

  final Map<String, int> _functionIndices;

  Environment()
      : _variables = [normalizedMap()],
        _variableIndices = normalizedMap(),
        _functions = [normalizedMap()],
        _functionIndices = normalizedMap();

  Environment._(this._variables, this._variableIndices, this._functions,
      this._functionIndices);

  Environment closure() => new Environment._(
      _variables.toList(),
      new Map.from(_variableIndices),
      _functions.toList(),
      new Map.from(_functionIndices));

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

  void setFunction(String name, Callable callable) {
    var index = _variables.length == 1
        ? 0
        : _variableIndices.putIfAbsent(name, () => _variables.length - 1);
    _functions[index][name] = callable;
  }

  /*=T*/ scope/*<T>*/(/*=T*/ callback()) {
    // TODO: avoid creating a new scope if no variables are declared.
    _variables.add({});
    try {
      return callback();
    } finally {
      for (var name in _variables.removeLast().keys) {
        _variableIndices.remove(name);
      }
    }
  }
}
