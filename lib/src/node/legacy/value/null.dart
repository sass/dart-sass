// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import '../../../value.dart';
import '../../reflection.dart';

/// The JS `sass.types.Null` class.
///
/// Unlike most other values, Node Sass nulls use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
final JSClass legacyNullClass = () {
  var jsClass = createJSClass('sass.types.Null', (dynamic _, [dynamic __]) {
    throw "new sass.types.Null() isn't allowed. Use sass.types.Null.NULL "
        "instead.";
  });
  setProperty(jsClass, "NULL", sassNull);

  getJSClass(sassNull).injectSuperclass(jsClass);
  return jsClass;
}();
