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

  /// The overloads declared for this callable.
  final _overloads = <Tuple2<ArgumentDeclaration, _Callback>>[];

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  ///
  /// The argument declaration is parsed from [arguments], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  AsyncBuiltInCallable(String name, String arguments,
      FutureOr<Value> callback(List<Value> arguments))
      : this.parsed(name, ArgumentDeclaration.parse(arguments), callback);

  /// Creates a callable with a single [arguments] declaration and a single
  /// [callback].
  AsyncBuiltInCallable.parsed(this.name, ArgumentDeclaration arguments,
      FutureOr<Value> callback(List<Value> arguments)) {
    _overloads.add(Tuple2(arguments, callback));
  }

  /// Creates a callable with multiple implementations.
  ///
  /// Each key/value pair in [overloads] defines the argument declaration for
  /// the overload (which should not include parentheses), and the callback to
  /// execute if that argument declaration matches. Throws a
  /// [SassFormatException] if parsing fails.
  AsyncBuiltInCallable.overloaded(this.name, Map<String, _Callback> overloads) {
    overloads.forEach((arguments, callback) {
      _overloads.add(Tuple2(ArgumentDeclaration.parse(arguments), callback));
    });
  }

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
}
