// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import '../../../value.dart';
import '../../reflection.dart';

/// The JS `sass.types.Boolean` class.
///
/// Unlike most other values, Node Sass booleans use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
final JSClass legacyBooleanClass = () {
  var jsClass = createJSClass('sass.types.Boolean', (dynamic _, [dynamic __]) {
    throw "new sass.types.Boolean() isn't allowed.\n"
        "Use sass.types.Boolean.TRUE or sass.types.Boolean.FALSE instead.";
  });

  jsClass.defineMethod('getValue', (Object self) => identical(self, sassTrue));
  setProperty(jsClass, "TRUE", sassTrue);
  setProperty(jsClass, "FALSE", sassFalse);

  getJSClass(sassTrue).injectSuperclass(jsClass);
  return jsClass;
}();
