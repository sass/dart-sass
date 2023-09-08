// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import '../ast/sass.dart';
import '../value.dart';
import 'async.dart';

/// An [AsyncBuiltInCallable]'s callback.
typedef Callback = FutureOr<Value> Function(List<Value> arguments);

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
  final Callback _callback;

  /// Whether this callback could potentially accept an `@content` block.
  final bool acceptsContent;

  /// Creates a function with a single [arguments] declaration and a single
  /// [callback].
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// If passed, [url] is the URL of the module in which the function is
  /// defined.
  AsyncBuiltInCallable.function(String name, String arguments,
      FutureOr<Value> callback(List<Value> arguments), {Object? url})
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
      {Object? url, bool acceptsContent = false})
      : this.parsed(name,
            ArgumentDeclaration.parse('@mixin $name($arguments) {', url: url),
            (arguments) async {
          await callback(arguments);
          // We could encode the fact that functions return values and mixins
          // don't in the type system, but that would get very messy very
          // quickly so it's easier to just return Sass's `null` for mixins and
          // simply ignore it at the call site.
          return sassNull;
        });

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  AsyncBuiltInCallable.parsed(this.name, this._arguments, this._callback,
      {this.acceptsContent = false});

  /// Returns the argument declaration and Dart callback for the given
  /// positional and named arguments.
  ///
  /// If no exact match is found, finds the closest approximation. Note that this
  /// doesn't guarantee that [positional] and [names] are valid for the returned
  /// [ArgumentDeclaration].
  (ArgumentDeclaration, Callback) callbackFor(
          int positional, Set<String> names) =>
      (_arguments, _callback);
}
