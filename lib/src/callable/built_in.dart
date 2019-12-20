// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../callable.dart';
import '../value.dart';
import 'async_built_in.dart';

typedef _Callback = Value Function(List<Value> arguments);

/// A callable defined in Dart code.
///
/// Unlike user-defined callables, built-in callables support overloads. They
/// may declare multiple different callbacks with multiple different sets of
/// arguments. When the callable is invoked, the first callback with matching
/// arguments is invoked.
class BuiltInCallable implements Callable, AsyncBuiltInCallable {
  final String name;

  /// The overloads declared for this callable.
  final List<Tuple2<ArgumentDeclaration, _Callback>> _overloads;

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  BuiltInCallable(
      String name, String arguments, Value callback(List<Value> arguments))
      : this.parsed(name, ArgumentDeclaration.parse(arguments), callback);

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  BuiltInCallable.parsed(this.name, ArgumentDeclaration arguments,
      Value callback(List<Value> arguments))
      : _overloads = [Tuple2(arguments, callback)];

  /// Creates a callable with multiple implementations.
  ///
  /// Each key/value pair in [overloads] defines the argument declaration for
  /// the overload (which should not include parentheses), and the callback to
  /// execute if that argument declaration matches. Throws a
  /// [SassFormatException] if parsing fails.
  BuiltInCallable.overloaded(this.name, Map<String, _Callback> overloads)
      : _overloads = [
          for (var entry in overloads.entries)
            Tuple2(ArgumentDeclaration.parse(entry.key), entry.value)
        ];

  BuiltInCallable._(this.name, this._overloads);

  /// Returns the argument declaration and Dart callback for the given
  /// positional and named arguments.
  ///
  /// If no exact match is found, finds the closest approximation. Note that this
  /// doesn't guarantee that [positional] and [names] are valid for the returned
  /// [ArgumentDeclaration].
  Tuple2<ArgumentDeclaration, _Callback> callbackFor(
      int positional, Set<String> names) {
    Tuple2<ArgumentDeclaration, _Callback> fuzzyMatch;
    int minMismatchDistance;

    for (var overload in _overloads) {
      // Ideally, find an exact match.
      if (overload.item1.matches(positional, names)) return overload;

      var mismatchDistance = overload.item1.arguments.length - positional;

      if (minMismatchDistance != null) {
        if (mismatchDistance.abs() > minMismatchDistance.abs()) continue;
        // If two overloads have the same mismatch distance, favor the overload
        // that has more arguments.
        if (mismatchDistance.abs() == minMismatchDistance.abs() &&
            mismatchDistance < 0) continue;
      }

      minMismatchDistance = mismatchDistance;
      fuzzyMatch = overload;
    }

    return fuzzyMatch;
  }

  /// Returns a copy of this callable with the given [name].
  BuiltInCallable withName(String name) => BuiltInCallable._(name, _overloads);
}
