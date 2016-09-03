// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'value/boolean.dart';
import 'value/identifier.dart';
import 'visitor/interface/value.dart';
import 'visitor/serialize.dart';

export 'value/boolean.dart';
export 'value/color.dart';
export 'value/identifier.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/number.dart';
export 'value/string.dart';

abstract class Value {
  /// Whether the value will be represented in CSS as the empty string.
  bool get isBlank => false;

  bool get isTruthy => true;

  const Value();

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor);

  List<Value> asList() => [this];

  Value unaryPlus() => new SassIdentifier("+${valueToCss(this)}");

  Value unaryMinus() => new SassIdentifier("-${valueToCss(this)}");

  Value unaryDivide() => new SassIdentifier("/${valueToCss(this)}");

  Value unaryNot() => sassFalse;

  String toString() => valueToCss(this, inspect: true);
}
