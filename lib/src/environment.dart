// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'value.dart';

class Environment {
  /// Base is global scope.
  final _variables = [<String, Value>{}];

  final _variableIndices = <String, int>{};

  Value getVariable(String name) =>
      _variables[_variableIndices[name] ?? 0][name];

  void setVariable(String name, Value value, {bool global}) {
    var index = global ? 0 : _variableIndices[name] ?? _variables.length - 1;
    _variables[index][name] = value;
  }

  /*=T*/ scope/*<T>*/(/*=T*/ callback()) {
    // TODO: avoid creating a new scope if no variables are declared.
    _variables.add({});
    try {
      return callback();
    } finally {
      _variables.removeLast();
    }
  }
}
