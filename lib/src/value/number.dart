// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/value.dart';
import '../value.dart';

class SassNumber extends Value {
  static const precision = 5;

  final num value;

  SassNumber(this.value);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitNumber(this);

  Value unaryPlus() => this;

  Value unaryMinus() => new SassNumber(-value);

  String toString() => value.toString();
}
