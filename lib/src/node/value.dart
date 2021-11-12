// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../value.dart';
import 'immutable.dart';
import 'reflection.dart';

export 'value/argument_list.dart';
export 'value/boolean.dart';
export 'value/color.dart';
export 'value/function.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/number.dart';
export 'value/string.dart';

/// The JavaScript `Value` class.
final JSClass valueClass = () {
  var jsClass = getJSClass(sassNull).superclass;
  jsClass.setCustomInspect((self) => self.toString());

  jsClass.defineGetters({
    'asList': (Value self) => ImmutableList(self.asList),
    'hasBrackets': (Value self) => self.hasBrackets,
    'isTruthy': (Value self) => self.isTruthy,
    'realNull': (Value self) => self.realNull,
    'separator': (Value self) => self.separator.separator,
  });

  jsClass.defineMethods({
    'sassIndexToListIndex': (Value self, Value sassIndex, [String? name]) =>
        self.sassIndexToListIndex(sassIndex, name),
    'get': (Value self, num index) =>
        index < 1 && index >= -1 ? self : undefined,
    'assertBoolean': (Value self, [String? name]) => self.assertBoolean(name),
    'assertColor': (Value self, [String? name]) => self.assertColor(name),
    'assertFunction': (Value self, [String? name]) => self.assertFunction(name),
    'assertMap': (Value self, [String? name]) => self.assertMap(name),
    'assertNumber': (Value self, [String? name]) => self.assertNumber(name),
    'assertString': (Value self, [String? name]) => self.assertString(name),
    'tryMap': (Value self) => self.tryMap(),
    'equals': (Value self, Object? other) => self == other,
    // For unclear reasons, the `immutable` package sometimes passes an extra
    // argument to `hashCode()`.
    'hashCode': (Value self, [Object? _]) => self.hashCode,
    'toString': (Value self) => self.toString(),
  });

  return jsClass;
}();
