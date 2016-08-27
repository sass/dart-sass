// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass/statement.dart';
import '../callable.dart';
import '../value.dart';

typedef Value _Callback(List<Value> arguments);

class BuiltInCallable implements Callable {
  final _Callback callback;

  final String name;
  final ArgumentDeclaration arguments;

  BuiltInCallable(this.name, this.arguments,
      Value callback(List<Value> arguments))
      : callback = callback;
}