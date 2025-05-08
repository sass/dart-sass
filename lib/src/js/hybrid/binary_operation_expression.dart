// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression/binary_operation.dart';
import '../../ast/sass/expression.dart';
import 'span.dart';

extension type JSBinaryOperationExpression._(JSObject _) implements JSObject {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    BinaryOperationExpression(
            BinaryOperator.plus, Expression.bogus, Expression.bogus)
        .toJS
        .constructor
        .defineGetter('span'.toJS,
            ((JSBinaryOperationExpression self) => self.toDart.span.toJS).toJS);
  }

  BinaryOperationExpression get toDart => this as BinaryOperationExpression;
}

extension BinaryOperationExpressionToJS on BinaryOperationExpression {
  JSBinaryOperationExpression get toJS => this as JSBinaryOperationExpression;
}
