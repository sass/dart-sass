// Copyright 2025 Google Inc. Use of this source code is governed by an
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

extension type JSSassMap._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSMap> jsClass = () {
    var jsClass = JSClass<JSMap>(
        'sass.SassMap',
        ((JSMap self, [ImmutableMap? contents]) => contents == null
            ? const SassMap.empty()
            : SassMap(contents.toDart.cast<Value, Value>())).toJS)
      ..defineGetter(
        'contents'.toJS,
        ((JSSassMap self) => self.toDart.contents.cast<JSValue, JSValue>().toJS)
            .toJS,
      )
      ..defineMethod(
          'get'.toJS,
          (JSSassMap jsSelf, JSAny indexOrKey) {
            var self = jsSelf.toDart;
            if (indexOrKey.isA<JSNumber>()) {
              var index = indexOrKey.toDartInt;
              if (index < 0) index = self.lengthAsList + index;
              if (index < 0 || index >= self.lengthAsList) return undefined;

              var (key, value) = self.contents.pairs.elementAt(index);
              return SassList([key, value], ListSeparator.space).toJS;
            } else {
              return self.contents[indexOrKey]?.toJS ?? undefined;
            }
          }.toJS);

    const SassMap.empty().toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  SassMap get toDart => this as SassMap;
}

extension SassMapToJS on SassMap {
  JSSassMap get toJS => this as JSSassMap;
}
