// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../callable.dart';
import '../util/map.dart';
import '../value.dart';

typedef Callback = Value Function(List<Value> arguments);

/// A callable defined in Dart code.
///
/// Unlike user-defined callables, built-in callables support overloads. They
/// may declare multiple different callbacks with multiple different sets of
/// parameters. When the callable is invoked, the first callback with matching
/// parameters is invoked.
final class BuiltInCallable implements Callable, AsyncBuiltInCallable {
  final String name;

  /// The overloads declared for this callable.
  final List<(ParameterList, Callback)> _overloads;

  final bool acceptsContent;

  /// Creates a function with a single [parameters] declaration and a single
  /// [callback].
  ///
  /// The parameter declaration is parsed from [parameters], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// If passed, [url] is the URL of the module in which the function is
  /// defined.
  BuiltInCallable.function(
    String name,
    String parameters,
    Value callback(List<Value> arguments), {
    Object? url,
  }) : this.parsed(
          name,
          ParameterList.parse('@function $name($parameters) {', url: url),
          callback,
        );

  /// Creates a mixin with a single [parameters] declaration and a single
  /// [callback].
  ///
  /// The parameter declaration is parsed from [parameters], which should not
  /// include parentheses. Throws a [SassFormatException] if parsing fails.
  ///
  /// If passed, [url] is the URL of the module in which the mixin is
  /// defined.
  BuiltInCallable.mixin(
    String name,
    String parameters,
    void callback(List<Value> arguments), {
    Object? url,
    bool acceptsContent = false,
  }) : this.parsed(
          name,
          ParameterList.parse('@mixin $name($parameters) {', url: url),
          (arguments) {
            callback(arguments);
            return sassNull;
          },
          acceptsContent: acceptsContent,
        );

  /// Creates a callable with a single [parameters] declaration and a single
  /// [callback].
  BuiltInCallable.parsed(
    this.name,
    ParameterList parameters,
    Value callback(List<Value> arguments), {
    this.acceptsContent = false,
  }) : _overloads = [(parameters, callback)];

  /// Creates a function with multiple implementations.
  ///
  /// Each key/value pair in [overloads] defines the parameter declaration for
  /// the overload (which should not include parentheses), and the callback to
  /// execute if that parameter declaration matches. Throws a
  /// [SassFormatException] if parsing fails.
  ///
  /// If passed, [url] is the URL of the module in which the function is
  /// defined.
  BuiltInCallable.overloadedFunction(
    this.name,
    Map<String, Callback> overloads, {
    Object? url,
  })  : _overloads = [
          for (var (args, callback) in overloads.pairs)
            (
              ParameterList.parse('@function $name($args) {', url: url),
              callback,
            ),
        ],
        acceptsContent = false;

  BuiltInCallable._(this.name, this._overloads, this.acceptsContent);

  /// Returns the parameter declaration and Dart callback for the given
  /// positional and named parameters.
  ///
  /// If no exact match is found, finds the closest approximation. Note that this
  /// doesn't guarantee that [positional] and [names] are valid for the returned
  /// [ParameterList].
  (ParameterList, Callback) callbackFor(int positional, Set<String> names) {
    (ParameterList, Callback)? fuzzyMatch;
    int? minMismatchDistance;

    for (var overload in _overloads) {
      // Ideally, find an exact match.
      if (overload.$1.matches(positional, names)) return overload;

      var mismatchDistance = overload.$1.parameters.length - positional;

      if (minMismatchDistance != null) {
        if (mismatchDistance.abs() > minMismatchDistance.abs()) continue;
        // If two overloads have the same mismatch distance, favor the overload
        // that has more parameters.
        if (mismatchDistance.abs() == minMismatchDistance.abs() &&
            mismatchDistance < 0) {
          continue;
        }
      }

      minMismatchDistance = mismatchDistance;
      fuzzyMatch = overload;
    }

    if (fuzzyMatch != null) return fuzzyMatch;
    throw StateError("BuiltInCallable $name may not have empty overloads.");
  }

  /// Returns a copy of this callable with the given [name].
  BuiltInCallable withName(String name) =>
      BuiltInCallable._(name, _overloads, acceptsContent);

  /// Returns a copy of this callable that emits a deprecation warning.
  BuiltInCallable withDeprecationWarning(String module, [String? newName]) =>
      BuiltInCallable._(
          name,
          [
            for (var (declaration, function) in _overloads)
              (
                declaration,
                (args) {
                  warnForGlobalBuiltIn(module, newName ?? name);
                  return function(args);
                },
              ),
          ],
          acceptsContent);
}
