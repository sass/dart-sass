// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../callable.dart';
import '../value.dart';

typedef Value _Callback(List<Value> arguments);

class BuiltInCallable implements Callable {
  final String name;
  final List<ArgumentDeclaration> overloads;
  final List<_Callback> callbacks;

  BuiltInCallable(String name, ArgumentDeclaration arguments,
      Value callback(List<Value> arguments))
      : this.overloaded(name, [arguments], [callback]);

  BuiltInCallable.overloaded(this.name, Iterable<ArgumentDeclaration> arguments,
      Iterable<_Callback> callbacks)
      : overloads = new List.unmodifiable(arguments),
        callbacks = new List.unmodifiable(callbacks);
}
