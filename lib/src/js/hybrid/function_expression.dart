// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/argument_list.dart';
import '../../ast/sass/expression/function.dart';
import '../../util/span.dart';

extension type JSFunctionExpression._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    FunctionExpression('a', ArgumentList.bogus, bogusSpan)
        .toJS
        .constructor
        .defineGetter(
            'arguments'.toJS,
            ((JSFunctionExpression self) => self.toDart.arguments as JSObject)
                .toJS);
  }

  FunctionExpression get toDart => this as FunctionExpression;
}

extension FunctionExpressionToJS on FunctionExpression {
  JSFunctionExpression get toJS => this as JSFunctionExpression;
}
