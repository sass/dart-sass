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

  Value unaryPlus() => this;

  Value unaryMinus() => new SassNumber(-value);
}
