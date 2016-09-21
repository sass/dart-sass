// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'exception.dart';
import 'value/boolean.dart';
import 'value/color.dart';
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

  List<Value> get asList => [this];

  const Value();

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor);

  SassBoolean assertBoolean([String name]) {
    if (name == null) throw new InternalException("$this is not a boolean.");
    throw new InternalException("\$$name: $this is not a boolean.");
  }

  SassColor assertColor([String name]) {
    if (name == null) throw new InternalException("$this is not a color.");
    throw new InternalException("\$$name: $this is not a color.");
  }

  SassMap assertMap([String name]) {
    if (name == null) throw new InternalException("$this is not a map.");
    throw new InternalException("\$$name: $this is not a map.");
  }

  SassNumber assertNumber([String name]) {
    if (name == null) throw new InternalException("$this is not a number.");
    throw new InternalException("\$$name: $this is not a number.");
  }

  SassString assertString([String name]) {
    if (name == null) throw new InternalException("$this is not a string.");
    throw new InternalException("\$$name: $this is not a string.");
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
}
