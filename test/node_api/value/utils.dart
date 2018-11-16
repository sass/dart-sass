// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:test/test.dart';

import '../api.dart';
import '../utils.dart';

/// Parses [source] by way of a function call.
T parseValue<T>(String source) {
  T value;
  renderSync(RenderOptions(
      data: "a {b: foo(($source))}",
      functions: jsify({
        r"foo($value)": allowInterop(expectAsync1((T value_) {
          value = value_;
          return sass.types.Null.NULL;
        }))
      })));
  return value;
}

/// A matcher that matches values that are JS `instanceof` [type].
Matcher isJSInstanceOf(Function type) =>
    predicate((value) => instanceof(value, type), "to be an instance of $type");
