// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../value.dart';

/// The JS `sass.types.Null` class.
///
/// Unlike most other values, Node Sass nulls use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
extension type JSSassLegacyNull._(JSLegacyValue _) implements JSLegacyValue {
  static final JSClass<JSSassLegacyNull> jsClass = () {
    // TODO - dart-lang/sdk#61249: define this inline when `Never` works as a JS
    // interop type.
    void constructor([JSAny? _]) {
      throw "new sass.types.Null() isn't allowed. Use sass.types.Null.NULL "
          "instead.";
    }

    var jsClass = JSClass<JSSassLegacyNull>(constructor.toJS,
        name: 'sass.types.Null.NULL')
      ..defineStaticValueGetter("NULL".toJS, sassNull.toJSLegacy,
          enumerable: true);

    sassNull.toJSLegacy.constructor.injectSuperclass(jsClass);
    return jsClass;
  }();

  Value get toDart => sassNull;
}
