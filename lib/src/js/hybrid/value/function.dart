// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../callable.dart';
import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

extension type JSSassFunction._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSSassFunction> jsClass = () {
    var jsClass = JSClass<JSSassFunction>(
        'sass.SassFunction',
        (
          JSBoolean self,
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
              (List<Value> values) =>
                  callback.callAsFunctionVarArgs(null, values.cast<JSValue>().toJS),
            ),
          );
        }.toJS);

    SassFunction(Callable('f', '', (_) => sassNull))
        .toJS
        .constructor
        .injectSuperclass(jsClass);

    return jsClass;
  }();

  SassFunction get toDart => this as SassFunction;
}

extension SassFunctionToJS on SassFunction {
  JSSassFunction get toJS => this as JSSassFunction;
}
