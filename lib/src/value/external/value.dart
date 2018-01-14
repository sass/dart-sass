// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart' as internal;
import '../../value.dart' show ListSeparator;
import 'boolean.dart';
import 'color.dart';
import 'function.dart';
import 'map.dart';
import 'number.dart';
import 'string.dart';

export 'argument_list.dart';
export 'boolean.dart';
export 'color.dart';
export 'function.dart';
export 'list.dart';
export 'map.dart';
export 'number.dart';
export 'string.dart';

/// The SassScript `null` value.
Value get sassNull => internal.sassNull;

// TODO(nweiz): Just mark members as @internal when sdk#28066 is fixed.
//
// We separate out the externally-visible Value type and subtypes (in this
// directory) from the internally-visible types (in the parent directory) so
// that we can add members that are only accessible from within this package.

/// A SassScript value.
///
/// All SassScript values are unmodifiable. New values can be constructed using
/// subclass constructors like [new SassString]. Untyped values can be cast to
/// particular types using `assert*()` functions like [assertString], which
/// throw user-friendly error messages if they fail.
abstract class Value {
  /// Whether the value counts as `true` in an `@if` statement and other
  /// contexts.
  bool get isTruthy;

  /// The separator for this value as a list.
  ///
  /// All SassScript values can be used as lists. Maps count as lists of pairs,
  /// and all other values count as single-value lists.
  ListSeparator get separator;

  /// Whether this value as a list has brackets.
  ///
  /// All SassScript values can be used as lists. Maps count as lists of pairs,
  /// and all other values count as single-value lists.
  bool get hasBrackets;

  /// This value as a list.
  ///
  /// All SassScript values can be used as lists. Maps count as lists of pairs,
  /// and all other values count as single-value lists.
  List<Value> get asList;

  /// Converts [sassIndex] into a Dart-style index into the list returned by
  /// [asList].
  ///
  /// Sass indexes are one-based, while Dart indexes are zero-based. Sass
  /// indexes may also be negative in order to index from the end of the list.
  ///
  /// Throws a [SassScriptException] if [sassIndex] isn't a number, if that
  /// number isn't an integer, or if that integer isn't a valid index for
  /// [asList]. If [sassIndex] came from a function argument, [name] is the
  /// argument name (without the `$`). It's used for error reporting.
  int sassIndexToListIndex(Value sassIndex, [String name]);

  /// Throws a [SassScriptException] if [this] isn't a boolean.
  ///
  /// Note that generally, functions should use [isTruthy] rather than requiring
  /// a literal boolean.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassBoolean assertBoolean([String name]);

  /// Throws a [SassScriptException] if [this] isn't a color.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassColor assertColor([String name]);

  /// Throws a [SassScriptException] if [this] isn't a function reference.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassFunction assertFunction([String name]);

  /// Throws a [SassScriptException] if [this] isn't a map.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassMap assertMap([String name]);

  /// Throws a [SassScriptException] if [this] isn't a number.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassNumber assertNumber([String name]);

  /// Throws a [SassScriptException] if [this] isn't a string.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassString assertString([String name]);

  /// Returns a valid CSS representation of [this].
  ///
  /// Throws a [SassScriptException] if [this] can't be represented in plain
  /// CSS. Use [toString] instead to get a string representation even if this
  /// isn't valid CSS.
  String toCssString();

  /// Returns a string representation of [this].
  ///
  /// Note that this is equivalent to calling `inspect()` on the value, and thus
  /// won't reflect the user's output settings. [toCssString] should be used
  /// instead to convert [this] to CSS.
  String toString();
}
