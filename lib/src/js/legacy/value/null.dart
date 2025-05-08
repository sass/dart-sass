// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

/// The JS `sass.types.Null` class.
///
/// Unlike most other values, Node Sass nulls use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
extension type JSSassLegacyNull._(JSObject _) implements JSObject {
  static final JSClass<JSSassLegacyNull> legacyNullClass = () {
    var jsClass =
        JSClass('sass.types.Null', (JSSassLegacyNull self, [JSAny? _]) {
      throw "new sass.types.Null() isn't allowed. Use sass.types.Null.NULL "
          "instead.";
    })
          ..setProperty("NULL".toJS, sassNull.toJSLegacy);

    sassNull.toJSLegacy.constructor.injectSuperclass(jsClass);
    return jsClass;
  }();

  SassNull get toDart => sassNull;
}

extension SassNullToJSLegacy on SassNull {
  JSSassLegacyNull get toJSLegacy => this as JSSassLegacyNull;
}
