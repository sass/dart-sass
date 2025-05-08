// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

@JS("util")
external JSObject? get _util;

@JS("util.inspect.custom")
external JSSymbol get _inspectSymbol;

extension <T extends JSObject> on JSClass<T> {
  /// Injects [superclass] as this class's immediate superclass, otherwise
  /// preserving the inheritance chain.
  void injectSuperclass(JSClass superclass) {
    superclass.prototype.prototypeOf = this.superclass.prototype;
    prototype.prototypeOf = JSObjects.create(superclass.prototype);
  }

  /// Sets the custom inspect logic for this class to [body].
  void setCustomInspect(String inspect(T self)) {
    if (_util == null) return;
    defineMethod(_inspectSymbol,
      ((T self, JSAny? _, JSAny? __, [JSAny? ___]) => inspect(self)).toJS);
  }
}
