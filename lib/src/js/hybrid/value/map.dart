// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/map.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../value.dart';

extension SassMapToJS on SassMap {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassMap>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassMap>>(
        (([ImmutableMap? contents]) => contents == null
            ? const SassMap.empty().toJS
            : SassMap(contents.toDart.cast<Value, Value>()).toJS).toJS)
      ..defineGetter(
        'contents'.toJS,
        (UnsafeDartWrapper<SassMap> self) => self.toDart.contents
            .cast<UnsafeDartWrapper<Value>, UnsafeDartWrapper<Value>>()
            .toJSImmutable,
      )
      ..defineMethod(
          'get'.toJS,
          (UnsafeDartWrapper<SassMap> jsSelf, JSAny indexOrKey) {
            var self = jsSelf.toDart;
            if (indexOrKey.isA<JSNumber>()) {
              var index = (indexOrKey as JSNumber).toDartDouble.floor();
              if (index < 0) index = self.lengthAsList + index;
              if (index < 0 || index >= self.lengthAsList) return undefined;

              var (key, value) = self.contents.pairs.elementAt(index);
              return SassList([key, value], ListSeparator.space).toJS;
            } else {
              return self
                      .contents[(indexOrKey as UnsafeDartWrapper<Value>).toDart]
                      ?.toJS ??
                  undefined;
            }
          }.toJSCaptureThis);

    const SassMap.empty().toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassMap> get toJS => toUnsafeWrapper;
}
