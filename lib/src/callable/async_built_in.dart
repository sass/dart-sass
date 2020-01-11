// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../value.dart';
import 'async.dart';

/// An [AsyncBuiltInCallable]'s callback.
typedef _Callback = FutureOr<Value> Function(List<Value> arguments);

/// A callable defined in Dart code.
///
/// Unlike user-defined callables, built-in callables support overloads. They
/// may declare multiple different callbacks with multiple different sets of
/// arguments. When the callable is invoked, the first callback with matching
/// arguments is invoked.
class AsyncBuiltInCallable implements AsyncCallable {
  final String name;

  /// This callable's arguments.
  final ArgumentDeclaration _arguments;

  /// The callback to run when executing this callable.
  final _Callback _callback;

  /// Creates a function with a single [arguments] declaration and a single
  /// [callback].
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// If passed, [url] is the URL of the module in which the function is
  /// defined.
  AsyncBuiltInCallable.function(String name, String arguments,
      FutureOr<Value> callback(List<Value> arguments), {Object url})
      : this.parsed(
            name,
            ArgumentDeclaration.parse('@function $name($arguments) {',
                url: url),
            callback);

  /// Creates a mixin with a single [arguments] declaration and a single
  /// [callback].
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// If passed, [url] is the URL of the module in which the mixin is
  /// defined.
  AsyncBuiltInCallable.mixin(String name, String arguments,
      FutureOr<void> callback(List<Value> arguments),
      {Object url})
      : this.parsed(name,
            ArgumentDeclaration.parse('@mixin $name($arguments) {', url: url),
            (arguments) async {
          await callback(arguments);
          return null;
        });

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  AsyncBuiltInCallable.parsed(this.name, this._arguments, this._callback);

  /// Returns the argument declaration and Dart callback for the given
  /// positional and named arguments.
  ///
  /// If no exact match is found, finds the closest approximation. Note that this
  /// doesn't guarantee that [positional] and [names] are valid for the returned
  /// [ArgumentDeclaration].
  Tuple2<ArgumentDeclaration, _Callback> callbackFor(
          int positional, Set<String> names) =>
      Tuple2(_arguments, _callback);
}
