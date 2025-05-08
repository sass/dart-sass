// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:js_core/js_core.dart';
import 'package:sass/src/js/utils.dart';

import '../../value.dart';
import 'value/color.dart';
import 'value/list.dart';
import 'value/map.dart';
import 'value/number.dart';
import 'value/string.dart';

export 'value/boolean.dart';
export 'value/color.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/null.dart';
export 'value/number.dart';
export 'value/string.dart';

@anonymous
extension type JSLegacyValue._(JSObject _) implements JSObject {
  /// Unwraps a value wrapped with [ValueToJSLegacy.toJSLegacy].
  ///
  /// If [object] is a JS error, throws it.
  Value get toDart {
    if (this case Value value) return value;
    if (this['modernValue'] case Value value) return value;
    if (JSError.isA(this)) throw this;
    throw "$this (${this.jsTypeName}) must be a Sass value type.";
  }
}

extension ValueToJSLegacy on Value {
  /// Wraps this in a wrapper that exposes the Node Sass API for that value.
  JSLegacyValue get toJSLegacy => switch (this) {
        SassColor value => value.toJSLegacy,
        SassList value => value.toJSLegacy,
        SassMap value => value.toJSLegacy,
        SassNumber value => value.toJSLegacy,
        SassString value => value.toJSLegacy,
        _ => value as JSLegacyValue,
      };
}
