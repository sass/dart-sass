// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../value.dart';

/// The JS `sass.types.Boolean` class.
///
/// Unlike most other values, Node Sass booleans use the same representation as
/// Dart Sass booleans without an additional wrapper. However, they still have
/// to have a constructor injected into their inheritance chain so that
/// `instanceof` works properly.
extension type JSSassLegacyBoolean._(JSLegacyValue _) implements JSLegacyValue {
  static final JSClass<JSSassLegacyBoolean> jsClass = () {
    // TODO - dart-lang/sdk#61249: define this inline when `Never` works as a JS
    // interop type.
    void constructor([JSAny? _]) {
      throw "new sass.types.Boolean() isn't allowed.\n"
          "Use sass.types.Boolean.TRUE or sass.types.Boolean.FALSE instead.";
    }

    var jsClass = JSClass<JSSassLegacyBoolean>(constructor.toJS,
        name: 'sass.types.Boolean')
      ..defineMethod(
          'getValue'.toJS,
          ((JSSassLegacyBoolean self) => identical(self, sassTrue))
              .toJSCaptureThis)
      ..defineStaticValueGetters(
          {"TRUE": sassTrue.toJSLegacy, "FALSE": sassFalse.toJSLegacy},
          enumerable: true);

    sassTrue.toJSLegacy.constructor.injectSuperclass(jsClass);
    return jsClass;
  }();

  SassBoolean get toDart => this as SassBoolean;
}

extension SassBooleanToJSLegacy on SassBoolean {
  JSSassLegacyBoolean get toJSLegacy => this as JSSassLegacyBoolean;
}
