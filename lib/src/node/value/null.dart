// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'dart:js_util';

import '../../value.dart';
import '../utils.dart';

/// The JS constructor for the `sass.types.Null` class.
///
/// Unlike most other values, Node Sass nulls use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
final Function nullConstructor = () {
  var constructor = allowInterop(([dynamic _]) {
    throw "new sass.types.Null() isn't allowed. Use sass.types.Null.NULL "
        "instead.";
  });
  injectSuperclass(sassNull, constructor);
  setClassName(sassNull, "SassNull");
  forwardToString(constructor);
  setProperty(constructor, "NULL", sassNull);
  setToString(sassNull, () => "null");
  return constructor;
}();
