// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:js/js.dart';

import '../../value.dart';
import '../utils.dart';

/// The JS constructor for the `sass.types.Boolean` class.
///
/// Unlike most other values, Node Sass booleans use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
final Function booleanConstructor = () {
  var constructor = allowInterop(([_]) {
    throw "new sass.types.Boolean() isn't allowed.\n"
        "Use sass.types.Boolean.TRUE or sass.types.Boolean.FALSE instead.";
  });
  injectSuperclass(sassTrue, constructor);
  forwardToString(constructor);
  setProperty(getProperty(constructor, "prototype"), "getValue",
      allowInteropCaptureThis((thisArg) => identical(thisArg, sassTrue)));
  setProperty(constructor, "TRUE", sassTrue);
  setProperty(constructor, "FALSE", sassFalse);
  return constructor;
}();
