// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'value/boolean.dart';
import 'value/identifier.dart';
import 'visitor/value.dart';

export 'value/boolean.dart';
export 'value/identifier.dart';
export 'value/list.dart';
export 'value/number.dart';
export 'value/string.dart';

abstract class Value {
  /// Whether the value will be represented in CSS as the empty string.
  bool get isBlank => false;

  const Value();

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor);

  // TODO: call the proper stringifying method
  Value unaryPlus() => new SassIdentifier("+$this");

  Value unaryMinus() => new SassIdentifier("-$this");

  Value unaryDivide() => new SassIdentifier("/$this");

  Value unaryNot() => sassFalse;
}
