// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import 'ast/selector.dart';
import 'exception.dart';
import 'utils.dart';
import 'value/boolean.dart';
import 'value/calculation.dart';
import 'value/color.dart';
import 'value/function.dart';
import 'value/list.dart';
import 'value/map.dart';
import 'value/number.dart';
import 'value/string.dart';
import 'visitor/interface/value.dart';
import 'visitor/serialize.dart';

export 'value/argument_list.dart';
export 'value/boolean.dart';
export 'value/calculation.dart';
export 'value/color.dart';
export 'value/function.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/null.dart';
export 'value/number.dart' hide conversionFactor;
export 'value/string.dart';

/// A SassScript value.
///
/// All SassScript values are unmodifiable. New values can be constructed using
/// subclass constructors like [new SassString]. Untyped values can be cast to
/// particular types using `assert*()` functions like [assertString], which
/// throw user-friendly error messages if they fail.
///
/// {@category Value}
@sealed
abstract class Value {
  /// Whether the value counts as `true` in an `@if` statement and other
  /// contexts.
  bool get isTruthy => true;

  /// The separator for this value as a list.
  ///
  /// All SassScript values can be used as lists. Maps count as lists of pairs,
  /// and all other values count as single-value lists.
  ListSeparator get separator => ListSeparator.undecided;

  /// Whether this value as a list has brackets.
  ///
  /// All SassScript values can be used as lists. Maps count as lists of pairs,
  /// and all other values count as single-value lists.
  bool get hasBrackets => false;

  /// This value as a list.
  ///
  /// All SassScript values can be used as lists. Maps count as lists of pairs,
  /// and all other values count as single-value lists.
  List<Value> get asList => [this];

  /// The length of [asList].
  ///
  /// This is used to compute [sassIndexToListIndex] without allocating a new
  /// list.
  ///
  /// @nodoc
  @protected
  int get lengthAsList => 1;

  /// Whether the value will be represented in CSS as the empty string.
  ///
  /// @nodoc
  @internal
  bool get isBlank => false;

  /// Whether this is a value that CSS may treat as a number, such as `calc()`
  /// or `var()`.
  ///
  /// Functions that shadow plain CSS functions need to gracefully handle when
  /// these arguments are passed in.
  ///
  /// @nodoc
  @internal
  bool get isSpecialNumber => false;

  /// Whether this is a call to `var()`, which may be substituted in CSS for a
  /// custom property value.
  ///
  /// Functions that shadow plain CSS functions need to gracefully handle when
  /// these arguments are passed in.
  ///
  /// @nodoc
  @internal
  bool get isVar => false;

  /// Returns Dart's `null` value if this is [sassNull], and returns [this]
  /// otherwise.
  Value? get realNull => this;

  /// @nodoc
  const Value();

  /// Calls the appropriate visit method on [visitor].
  ///
  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor);

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
  int sassIndexToListIndex(Value sassIndex, [String? name]) {
    var index = sassIndex.assertNumber(name).assertInt(name);
    if (index == 0) throw _exception("List index may not be 0.", name);
    if (index.abs() > lengthAsList) {
      throw _exception(
          "Invalid index $sassIndex for a list with $lengthAsList elements.",
          name);
    }

    return index < 0 ? lengthAsList + index : index - 1;
  }

  /// Throws a [SassScriptException] if [this] isn't a boolean.
  ///
  /// Note that generally, functions should use [isTruthy] rather than requiring
  /// a literal boolean.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassBoolean assertBoolean([String? name]) =>
      throw _exception("$this is not a boolean.", name);

  /// Throws a [SassScriptException] if [this] isn't a calculation.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassCalculation assertCalculation([String? name]) =>
      throw _exception("$this is not a calculation.", name);

  /// Throws a [SassScriptException] if [this] isn't a color.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassColor assertColor([String? name]) =>
      throw _exception("$this is not a color.", name);

  /// Throws a [SassScriptException] if [this] isn't a function reference.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassFunction assertFunction([String? name]) =>
      throw _exception("$this is not a function reference.", name);

  /// Throws a [SassScriptException] if [this] isn't a map.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassMap assertMap([String? name]) =>
      throw _exception("$this is not a map.", name);

  /// Returns [this] as a [SassMap] if it is one (including empty lists, which
  /// count as empty maps) or returns `null` if it's not.
  SassMap? tryMap() => null;

  /// Throws a [SassScriptException] if [this] isn't a number.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassNumber assertNumber([String? name]) =>
      throw _exception("$this is not a number.", name);

  /// Throws a [SassScriptException] if [this] isn't a string.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassString assertString([String? name]) =>
      throw _exception("$this is not a string.", name);

  /// Parses [this] as a selector list, in the same manner as the
  /// `selector-parse()` function.
  ///
  /// Throws a [SassScriptException] if this isn't a type that can be parsed as a
  /// selector, or if parsing fails. If [allowParent] is `true`, this allows
  /// [ParentSelector]s. Otherwise, they're considered parse errors.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  ///
  /// @nodoc
  @internal
  SelectorList assertSelector({String? name, bool allowParent = false}) {
    var string = _selectorString(name);
    try {
      return SelectorList.parse(string, allowParent: allowParent);
    } on SassFormatException catch (error, stackTrace) {
      // TODO(nweiz): colorize this if we're running in an environment where
      // that works.
      throwWithTrace(
          _exception(error.toString().replaceFirst("Error: ", ""), name),
          stackTrace);
    }
  }

  /// Parses [this] as a simple selector, in the same manner as the
  /// `selector-parse()` function.
  ///
  /// Throws a [SassScriptException] if this isn't a type that can be parsed as a
  /// selector, or if parsing fails. If [allowParent] is `true`, this allows
  /// [ParentSelector]s. Otherwise, they're considered parse errors.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  ///
  /// @nodoc
  @internal
  SimpleSelector assertSimpleSelector(
      {String? name, bool allowParent = false}) {
    var string = _selectorString(name);
    try {
      return SimpleSelector.parse(string, allowParent: allowParent);
    } on SassFormatException catch (error, stackTrace) {
      // TODO(nweiz): colorize this if we're running in an environment where
      // that works.
      throwWithTrace(
          _exception(error.toString().replaceFirst("Error: ", ""), name),
          stackTrace);
    }
  }

  /// Parses [this] as a compound selector, in the same manner as the
  /// `selector-parse()` function.
  ///
  /// Throws a [SassScriptException] if this isn't a type that can be parsed as a
  /// selector, or if parsing fails. If [allowParent] is `true`, this allows
  /// [ParentSelector]s. Otherwise, they're considered parse errors.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  ///
  /// @nodoc
  @internal
  CompoundSelector assertCompoundSelector(
      {String? name, bool allowParent = false}) {
    var string = _selectorString(name);
    try {
      return CompoundSelector.parse(string, allowParent: allowParent);
    } on SassFormatException catch (error, stackTrace) {
      // TODO(nweiz): colorize this if we're running in an environment where
      // that works.
      throwWithTrace(
          _exception(error.toString().replaceFirst("Error: ", ""), name),
          stackTrace);
    }
  }

  /// Converts a `selector-parse()`-style input into a string that can be
  /// parsed.
  ///
  /// Throws a [SassScriptException] if [this] isn't a type or a structure that
  /// can be parsed as a selector.
  String _selectorString([String? name]) {
    var string = _selectorStringOrNull();
    if (string != null) return string;

    throw _exception(
        "$this is not a valid selector: it must be a string,\n"
        "a list of strings, or a list of lists of strings.",
        name);
  }

  /// Converts a `selector-parse()`-style input into a string that can be
  /// parsed.
  ///
  /// Returns `null` if [this] isn't a type or a structure that can be parsed as
  /// a selector.
  String? _selectorStringOrNull() {
    if (this is SassString) return (this as SassString).text;
    if (this is! SassList) return null;
    var list = this as SassList;
    if (list.asList.isEmpty) return null;

    var result = <String>[];
    switch (list.separator) {
      case ListSeparator.comma:
        for (var complex in list.asList) {
          if (complex is SassString) {
            result.add(complex.text);
          } else if (complex is SassList &&
              complex.separator == ListSeparator.space) {
            var string = complex._selectorStringOrNull();
            if (string == null) return null;
            result.add(string);
          } else {
            return null;
          }
        }
        break;
      case ListSeparator.slash:
        return null;
      default:
        for (var compound in list.asList) {
          if (compound is SassString) {
            result.add(compound.text);
          } else {
            return null;
          }
        }
        break;
    }
    return result.join(list.separator == ListSeparator.comma ? ', ' : ' ');
  }

  /// Returns a new list containing [contents] that defaults to this value's
  /// separator and brackets.
  SassList withListContents(Iterable<Value> contents,
      {ListSeparator? separator, bool? brackets}) {
    return SassList(contents, separator ?? this.separator,
        brackets: brackets ?? hasBrackets);
  }

  /// The SassScript `=` operation.
  ///
  /// @nodoc
  @internal
  Value singleEquals(Value other) =>
      SassString("${toCssString()}=${other.toCssString()}", quotes: false);

  /// The SassScript `>` operation.
  ///
  /// @nodoc
  @internal
  SassBoolean greaterThan(Value other) =>
      throw SassScriptException('Undefined operation "$this > $other".');

  /// The SassScript `>=` operation.
  ///
  /// @nodoc
  @internal
  SassBoolean greaterThanOrEquals(Value other) =>
      throw SassScriptException('Undefined operation "$this >= $other".');

  /// The SassScript `<` operation.
  ///
  /// @nodoc
  @internal
  SassBoolean lessThan(Value other) =>
      throw SassScriptException('Undefined operation "$this < $other".');

  /// The SassScript `<=` operation.
  ///
  /// @nodoc
  @internal
  SassBoolean lessThanOrEquals(Value other) =>
      throw SassScriptException('Undefined operation "$this <= $other".');

  /// The SassScript `*` operation.
  ///
  /// @nodoc
  @internal
  Value times(Value other) =>
      throw SassScriptException('Undefined operation "$this * $other".');

  /// The SassScript `%` operation.
  ///
  /// @nodoc
  @internal
  Value modulo(Value other) =>
      throw SassScriptException('Undefined operation "$this % $other".');

  /// The SassScript `+` operation.
  ///
  /// @nodoc
  @internal
  Value plus(Value other) {
    if (other is SassString) {
      return SassString(toCssString() + other.text, quotes: other.hasQuotes);
    } else if (other is SassCalculation) {
      throw SassScriptException('Undefined operation "$this + $other".');
    } else {
      return SassString(toCssString() + other.toCssString(), quotes: false);
    }
  }

  /// The SassScript `-` operation.
  ///
  /// @nodoc
  @internal
  Value minus(Value other) {
    if (other is SassCalculation) {
      throw SassScriptException('Undefined operation "$this - $other".');
    } else {
      return SassString("${toCssString()}-${other.toCssString()}",
          quotes: false);
    }
  }

  /// The SassScript `/` operation.
  ///
  /// @nodoc
  @internal
  Value dividedBy(Value other) =>
      SassString("${toCssString()}/${other.toCssString()}", quotes: false);

  /// The SassScript unary `+` operation.
  ///
  /// @nodoc
  @internal
  Value unaryPlus() => SassString("+${toCssString()}", quotes: false);

  /// The SassScript unary `-` operation.
  ///
  /// @nodoc
  @internal
  Value unaryMinus() => SassString("-${toCssString()}", quotes: false);

  /// The SassScript unary `/` operation.
  ///
  /// @nodoc
  @internal
  Value unaryDivide() => SassString("/${toCssString()}", quotes: false);

  /// The SassScript unary `not` operation.
  ///
  /// @nodoc
  @internal
  Value unaryNot() => sassFalse;

  /// Returns a copy of [this] without [SassNumber.asSlash] set.
  ///
  /// If this isn't a [SassNumber], returns it as-is.
  ///
  /// @nodoc
  @internal
  Value withoutSlash() => this;

  /// Returns a valid CSS representation of [this].
  ///
  /// Throws a [SassScriptException] if [this] can't be represented in plain
  /// CSS. Use [toString] instead to get a string representation even if this
  /// isn't valid CSS.
  //
  // Internal-only: If [quote] is `false`, quoted strings are emitted without
  // quotes.
  String toCssString({@internal bool quote = true}) =>
      serializeValue(this, quote: quote);

  /// Returns a string representation of [this].
  ///
  /// Note that this is equivalent to calling `inspect()` on the value, and thus
  /// won't reflect the user's output settings. [toCssString] should be used
  /// instead to convert [this] to CSS.
  String toString() => serializeValue(this, inspect: true);

  /// Throws a [SassScriptException] with the given [message].
  SassScriptException _exception(String message, [String? name]) =>
      SassScriptException(name == null ? message : "\$$name: $message");
}
