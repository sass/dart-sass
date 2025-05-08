// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../utils.dart';
import '../value.dart';

extension SassListToJS on SassList {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassList>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassList>>(([
      JSObject? contentsOrOptions,
      _ConstructorOptions? options,
    ]) {
      List<Value> contents;
      if (ImmutableList.isA(contentsOrOptions)) {
        contents =
            (contentsOrOptions as ImmutableList<UnsafeDartWrapper<Value>>)
                .toDart
                .cast<Value>();
      } else if (contentsOrOptions.isA<JSArray<UnsafeDartWrapper<Value>>>()) {
        contents = (contentsOrOptions as JSArray<UnsafeDartWrapper<Value>>)
            .toDart
            .cast<Value>();
      } else {
        contents = [];
        options = contentsOrOptions as _ConstructorOptions?;
      }

      return SassList(
        contents,
        options == null || options.separator.isUndefined
            ? ListSeparator.comma
            : parseSeparator(options.separator?.toDart),
        brackets: options?.brackets ?? false,
      ).toJS;
    }.toJS)
      ..defineMethod(
          'get'.toJS,
          (UnsafeDartWrapper<SassList> jsSelf, num indexFloat) {
            var self = jsSelf.toDart;
            var index = indexFloat.floor();
            if (index < 0) index = self.asList.length + index;
            if (index < 0 || index >= self.asList.length) return undefined;
            return self.asList[index].toJS;
          }.toJSCaptureThis);

    const SassList.empty().toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassList> get toJS => toUnsafeWrapper;
}

extension type _ConstructorOptions(JSObject _) implements JSObject {
  external JSString? get separator;
  external bool? get brackets;
}
