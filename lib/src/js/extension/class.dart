// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

@JS("util")
external JSObject? get _util;

@JS("util.inspect.custom")
external JSSymbol get _inspectSymbol;

extension JSClassExtension<T extends JSAny> on JSClass<T> {
  /// Injects [superclass] as this class's immediate superclass, otherwise
  /// preserving the inheritance chain.
  void injectSuperclass(JSClass superclass) {
    if (this.superclass?.prototype case var grandPrototype?) {
      superclass.prototype.prototypeOf = grandPrototype;
    }
    prototype.prototypeOf = JSObjectLike.createUnsafe(superclass.prototype);
  }

  /// Sets the custom inspect logic for this class to [body].
  void setCustomInspect(String inspect(T self)) {
    if (_util == null) return;
    defineMethod(
        _inspectSymbol,
        ((T self, JSAny? _, JSAny? __, [JSAny? ___]) => inspect(self))
            .toJSCaptureThis);
  }
}
