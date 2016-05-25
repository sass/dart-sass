// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'value/boolean.dart';
import 'value/identifier.dart';

export 'value/boolean.dart';
export 'value/identifier.dart';
export 'value/list.dart';
export 'value/string.dart';

abstract class Value {
  const Value();

  // TODO: call the proper stringifying method
  Value unaryPlus() => new Identifier("+$this");

  Value unaryMinus() => new Identifier("-$this");

  Value unaryDivide() => new Identifier("/$this");

  Value unaryNot() => Boolean.sassFalse;
}
