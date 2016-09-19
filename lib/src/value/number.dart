// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../exception.dart';
import '../utils.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

class SassNumber extends Value {
  static const precision = 10;

  final num value;

  bool get isInt => value is int || almostEquals(value % 1, 0.0);

  int get asInt {
    if (!isInt) throw new InternalException("$this is not an int.");
    return value.round();
  }

  SassNumber(this.value);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitNumber(this);

  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) return new SassBoolean(value > other.value);
    throw new InternalException('Undefined operation "$this > $other".');
  }

  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) return new SassBoolean(value >= other.value);
    throw new InternalException('Undefined operation "$this >= $other".');
  }

  SassBoolean lessThan(Value other) {
    if (other is SassNumber) return new SassBoolean(value < other.value);
    throw new InternalException('Undefined operation "$this < $other".');
  }

  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) return new SassBoolean(value <= other.value);
    throw new InternalException('Undefined operation "$this <= $other".');
  }

  Value times(Value other) {
    if (other is SassNumber) return new SassNumber(value * other.value);
    throw new InternalException('Undefined operation "$this * $other".');
  }

  Value modulo(Value other) {
    if (other is SassNumber) return new SassNumber(value % other.value);
    throw new InternalException('Undefined operation "$this % $other".');
  }

  Value plus(Value other) {
    if (other is SassNumber) return new SassNumber(value + other.value);
    if (other is! SassColor) return super.plus(other);
    throw new InternalException('Undefined operation "$this + $other".');
  }

  Value minus(Value other) {
    if (other is SassNumber) return new SassNumber(value - other.value);
    if (other is! SassColor) return super.minus(other);
    throw new InternalException('Undefined operation "$this - $other".');
  }

  Value dividedBy(Value other) {
    if (other is SassNumber) return new SassNumber(value / other.value);
    if (other is! SassColor) super.dividedBy(other);
    throw new InternalException('Undefined operation "$this / $other".');
  }

  Value unaryPlus() => this;

  Value unaryMinus() => new SassNumber(-value);
}
