// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../callable.dart';
import '../value.dart';

/// A [BuiltInCallable]'s callback.
typedef Value _Callback(List<Value> arguments);

/// A callable defined in Dart code.
///
/// Unlike user-defined callables, built-in callables support overloads. They
/// may declare multiple different callbacks with multiple different sets of
/// arguments. When the callable is invoked, the first callback with matching
/// arguments is invoked.
class BuiltInCallable implements Callable {
  final String name;

  /// The arguments declared for this callable.
  ///
  /// The declaration at index `i` corresponds to the callback at index `i` in
  /// [callbacks].
  final List<ArgumentDeclaration> overloads;

  /// The callbacks declared for this callable.
  ///
  /// The callback at index `i` corresponds to the arguments at index `i` in
  /// [overloads].
  final List<_Callback> callbacks;

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  BuiltInCallable(
      String name, String arguments, Value callback(List<Value> arguments))
      : this.overloaded(name, [arguments], [callback]);

  /// Creates a callable that declares multiple overloads.
  ///
  /// The argument declarations are parsed from [overloads], whose contents
  /// should not include parentheses. Throws a [SassFormatException] if parsing
  /// fails.
  ///
  /// Throws an [ArgumentError] if [overloads] doesn't have the same length as
  /// [callbacks].
  BuiltInCallable.overloaded(
      this.name, Iterable<String> overloads, Iterable<_Callback> callbacks)
      : overloads = new List.unmodifiable(overloads
            .map((overload) => new ArgumentDeclaration.parse("$overload"))),
        callbacks = new List.unmodifiable(callbacks) {
    if (this.overloads.length != this.callbacks.length) {
      throw new ArgumentError(
          "overloads must be the same length as callbacks.");
    }
  }
}
