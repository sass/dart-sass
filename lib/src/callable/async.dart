// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import '../value.dart';
import 'async_built_in.dart';

/// An interface for objects, such as functions and mixins, that can be invoked
/// from Sass by passing in arguments.
///
/// This class represents callables that *need* to do asynchronous work. It's
/// only compatible with the asynchonous `compile()` methods. If a callback can
/// work synchronously, it should be a [Callable] instead.
abstract class AsyncCallable {
  /// The callable's name.
  String get name;

  factory AsyncCallable(String name, String arguments,
      FutureOr<Value> callback(List<Value> arguments)) = AsyncBuiltInCallable;
}
