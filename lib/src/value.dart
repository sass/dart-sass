// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/selector.dart';
import 'exception.dart';
import 'value/boolean.dart';
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
export 'value/color.dart';
export 'value/function.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/null.dart';
export 'value/number.dart';
export 'value/string.dart';

/// A SassScript value.
///
/// Note that all SassScript values are unmodifiable.
abstract class Value {
  /// Whether the value will be represented in CSS as the empty string.
  bool get isBlank => false;

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

  /// Whether this is a `calc()` expression.
  ///
  /// Functions that shadow plain CSS functions need to gracefully handle when
  /// `calc()`-derived arguments are passed in.
  bool get isCalc => false;

  const Value();

  /// Calls the appropriate visit method on [visitor].
  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor);

  /// Throws a [SassScriptException] if [this] isn't a boolean.
  ///
  /// Note that generally, functions should use [isTruthy] rather than requiring
  /// a literal boolean.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SassBoolean assertBoolean([String name]) =>
      throw _exception("$this is not a boolean.", name);

  /// Throws a [SassScriptException] if [this] isn't a color.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SassColor assertColor([String name]) =>
      throw _exception("$this is not a color.", name);

  /// Throws a [SassScriptException] if [this] isn't a function reference.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SassFunction assertFunction([String name]) =>
      throw _exception("$this is not a function reference.", name);

  /// Throws a [SassScriptException] if [this] isn't a map.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SassMap assertMap([String name]) =>
      throw _exception("$this is not a map.", name);

  /// Throws a [SassScriptException] if [this] isn't a number.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SassNumber assertNumber([String name]) =>
      throw _exception("$this is not a number.", name);

  /// Throws a [SassScriptException] if [this] isn't a string.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SassString assertString([String name]) =>
      throw _exception("$this is not a string.", name);

  /// Parses [this] as a selector list, in the same manner as the
  /// `selector-parse()` function.
  ///
  /// Throws a [SassScriptException] if this isn't a type that can be parsed as a
  /// selector, or if parsing fails. If [allowParent] is `true`, this allows
  /// [ParentSelector]s. Otherwise, they're considered parse errors.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  SelectorList assertSelector({String name, bool allowParent: false}) {
    var string = _selectorString(name);
    try {
      return new SelectorList.parse(string, allowParent: allowParent);
    } on SassFormatException catch (error) {
      // TODO(nweiz): colorize this if we're running in an environment where
      // that works.
      throw _exception(error.toString());
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
  /// (without the `$`). It's used for debugging.
  SimpleSelector assertSimpleSelector({String name, bool allowParent: false}) {
    var string = _selectorString(name);
    try {
      return new SimpleSelector.parse(string, allowParent: allowParent);
    } on SassFormatException catch (error) {
      // TODO(nweiz): colorize this if we're running in an environment where
      // that works.
      throw _exception(error.toString());
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
  /// (without the `$`). It's used for debugging.
  CompoundSelector assertCompoundSelector(
      {String name, bool allowParent: false}) {
    var string = _selectorString(name);
    try {
      return new CompoundSelector.parse(string, allowParent: allowParent);
    } on SassFormatException catch (error) {
      // TODO(nweiz): colorize this if we're running in an environment where
      // that works.
      throw _exception(error.toString());
    }
  }

  /// Converts a `selector-parse()`-style input into a string that can be
  /// parsed.
  ///
  /// Throws a [SassScriptException] if [this] isn't a type or a structure that
  /// can be parsed as a selector.
  String _selectorString([String name]) {
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
  String _selectorStringOrNull() {
    if (this is SassString) return (this as SassString).text;
    if (this is! SassList) return null;
    var list = this as SassList;
    if (list.contents.isEmpty) return null;

    var result = <String>[];
    if (list.separator == ListSeparator.comma) {
      for (var complex in list.contents) {
        if (complex is SassString) {
          result.add(complex.text);
        } else if (complex is SassList &&
            complex.separator == ListSeparator.space) {
          var string = complex._selectorString();
          if (string == null) return null;
          result.add(string);
        } else {
          return null;
        }
      }
    } else {
      for (var compound in list.contents) {
        if (compound is SassString) {
          result.add(compound.text);
        } else {
          return null;
        }
      }
    }
    return result.join(list.separator == ListSeparator.comma ? ', ' : ' ');
  }

  /// Returns a new list containing [contents] that defaults to this value's
  /// separator and brackets.
  SassList changeListContents(Iterable<Value> contents,
      {ListSeparator separator, bool brackets}) {
    return new SassList(contents, separator ?? this.separator,
        brackets: brackets ?? this.hasBrackets);
  }

  /// The SassScript `or` operation.
  Value or(Value other) => this;

  /// The SassScript `and` operation.
  Value and(Value other) => other;

  /// The SassScript `>` operation.
  SassBoolean greaterThan(Value other) =>
      throw new SassScriptException('Undefined operation "$this > $other".');

  /// The SassScript `>=` operation.
  SassBoolean greaterThanOrEquals(Value other) =>
      throw new SassScriptException('Undefined operation "$this >= $other".');

  /// The SassScript `<` operation.
  SassBoolean lessThan(Value other) =>
      throw new SassScriptException('Undefined operation "$this < $other".');

  /// The SassScript `<=` operation.
  SassBoolean lessThanOrEquals(Value other) =>
      throw new SassScriptException('Undefined operation "$this <= $other".');

  /// The SassScript `*` operation.
  Value times(Value other) =>
      throw new SassScriptException('Undefined operation "$this * $other".');

  /// The SassScript `%` operation.
  Value modulo(Value other) =>
      throw new SassScriptException('Undefined operation "$this % $other".');

  /// The SassScript `+` operation.
  Value plus(Value other) {
    if (other is SassString) {
      return new SassString(toCssString() + other.text,
          quotes: other.hasQuotes);
    } else {
      return new SassString(toCssString() + other.toCssString());
    }
  }

  /// The SassScript `-` operation.
  Value minus(Value other) =>
      new SassString("${toCssString()}-${other.toCssString()}");

  /// The SassScript `/` operation.
  Value dividedBy(Value other) =>
      new SassString("${toCssString()}/${other.toCssString()}");

  /// The SassScript unary `+` operation.
  Value unaryPlus() => new SassString("+${toCssString()}");

  /// The SassScript unary `-` operation.
  Value unaryMinus() => new SassString("-${toCssString()}");

  /// The SassScript unary `/` operation.
  Value unaryDivide() => new SassString("/${toCssString()}");

  /// The SassScript unary `not` operation.
  Value unaryNot() => sassFalse;

  /// Returns a copy of [this] without [SassNumber.asSlash] set.
  ///
  /// If this isn't a [SassNumber], returns it as-is.
  Value withoutSlash() => this;

  /// Returns a valid CSS representation of [this].
  ///
  /// Throws a [SassScriptException] if [this] can't be represented in plain
  /// CSS. Use [toString] instead to get a string representation even if this
  /// isn't valid CSS.
  ///
  /// If [quote] is `false`, quoted strings are emitted without quotes.
  String toCssString({bool quote: true}) => valueToCss(this, quote: quote);

  /// Returns a string representation of [this].
  ///
  /// Note that this is equivalent to calling `inspect()` on the value, and thus
  /// won't reflect the user's output settings. [toCssString] should be used
  /// instead to convert [this] to CSS.
  String toString() => valueToCss(this, inspect: true);

  /// Throws a [SassScriptException] with the given [message].
  SassScriptException _exception(String message, [String name]) =>
      new SassScriptException(name == null ? message : "\$$name: $message");
}
