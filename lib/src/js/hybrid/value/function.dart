// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../callable.dart';
import '../../../value.dart';
import '../../extension/class.dart';
import '../value.dart';

extension SassFunctionToJS on SassFunction {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassFunction>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassFunction>>((
      String signature,
      JSFunction callback,
    ) {
      var paren = signature.indexOf('(');
      if (paren == -1 || !signature.endsWith(')')) {
        JSError.throwLikeJS(
          JSError(
              'Invalid signature for new sass.SassFunction(): "$signature"'),
        );
      }

      return SassFunction(
        Callable(
          signature.substring(0, paren),
          signature.substring(paren + 1, signature.length - 1),
          (List<Value> values) => (callback.callAsFunction(
                      null, values as JSArray<UnsafeDartWrapper<Value>>)
                  as UnsafeDartWrapper<Value>)
              .toDart,
        ),
      ).toJS;
    }.toJS);

    SassFunction(Callable('f', '', (_) => sassNull))
        .toJS
        .constructor
        .injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassFunction> get toJS => toUnsafeWrapper;
}
