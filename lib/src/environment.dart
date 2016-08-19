// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'value.dart';
import 'utils.dart';

class Environment {
  /// Base is global scope.
  final _variables = [separatorIndependentMap/*<Value>*/()];

  final _variableIndices = separatorIndependentMap/*<int>*/();

  Value getVariable(String name) =>
      _variables[_variableIndices[name] ?? 0][name];

  void setVariable(String name, Value value, {bool global}) {
    var index = global || _variables.length == 1
        ? 0
        : _variableIndices.putIfAbsent(name, () => _variables.length - 1);
    _variables[index][name] = value;
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
