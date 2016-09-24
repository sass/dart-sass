// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/selector.dart';
import 'exception.dart';
import 'value/boolean.dart';
import 'value/color.dart';
import 'value/list.dart';
import 'value/map.dart';
import 'value/number.dart';
import 'value/string.dart';
import 'visitor/interface/value.dart';
import 'visitor/serialize.dart';

export 'value/argument_list.dart';
export 'value/boolean.dart';
export 'value/color.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/null.dart';
export 'value/number.dart';
export 'value/string.dart';

abstract class Value {
  /// Whether the value will be represented in CSS as the empty string.
  bool get isBlank => false;

  bool get isTruthy => true;

  ListSeparator get separator => ListSeparator.undecided;

  bool get hasBrackets => false;

  List<Value> get asList => [this];

  const Value();

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor);

  SassBoolean assertBoolean([String name]) =>
      throw _exception("$this is not a boolean.", name);

  SassColor assertColor([String name]) =>
      throw _exception("$this is not a color.", name);

  SassMap assertMap([String name]) =>
      throw _exception("$this is not a map.", name);

  SassNumber assertNumber([String name]) =>
      throw _exception("$this is not a number.", name);

  SassString assertString([String name]) =>
      throw _exception("$this is not a string.", name);

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

  String _selectorString([String name]) {
    var string = _selectorStringOrNull();
    if (string != null) return string;

    throw _exception(
        "$this is not a valid selector: it must be a string,\n"
        "a list of strings, or a list of lists of strings.",
        name);
  }

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
    return result.join(', ');
  }

  // Note that if [contents] has length > 1, [separator] may not be undecided.
  SassList changeListContents(Iterable<Value> contents,
      {ListSeparator separator, bool brackets}) {
    return new SassList(contents, separator ?? this.separator,
        brackets: brackets ?? this.hasBrackets);
  }

  Value or(Value other) => this;

  Value and(Value other) => other;

  SassBoolean greaterThan(Value other) =>
      throw new InternalException('Undefined operation "$this > $other".');

  SassBoolean greaterThanOrEquals(Value other) =>
      throw new InternalException('Undefined operation "$this >= $other".');

  SassBoolean lessThan(Value other) =>
      throw new InternalException('Undefined operation "$this < $other".');

  SassBoolean lessThanOrEquals(Value other) =>
      throw new InternalException('Undefined operation "$this <= $other".');

  Value times(Value other) =>
      throw new InternalException('Undefined operation "$this * $other".');

  Value modulo(Value other) =>
      throw new InternalException('Undefined operation "$this % $other".');

  Value plus(Value other) {
    if (other is SassString) {
      return new SassString(valueToCss(this) + other.text,
          quotes: other.hasQuotes);
    } else {
      return new SassString(valueToCss(this) + valueToCss(other));
    }
  }

  Value minus(Value other) =>
      new SassString("${valueToCss(this)}-${valueToCss(other)}");

  Value dividedBy(Value other) =>
      new SassString("${valueToCss(this)}/${valueToCss(other)}");

  Value unaryPlus() => new SassString("+${valueToCss(this)}");

  Value unaryMinus() => new SassString("-${valueToCss(this)}");

  Value unaryDivide() => new SassString("/${valueToCss(this)}");

  Value unaryNot() => sassFalse;

  String toString() => valueToCss(this, inspect: true);

  InternalException _exception(String message, [String name]) =>
      new InternalException(name == null ? message : "\$$name: $message");
}
