// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression/binary_operation.dart';
import '../../ast/sass/expression.dart';
import 'file_span.dart';

extension BinaryOperationExpressionToJS on BinaryOperationExpression {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() => BinaryOperationExpression(
          BinaryOperator.plus, Expression.bogus, Expression.bogus)
      .toJS
      .constructor
      .defineGetter(
          'span'.toJS,
          (UnsafeDartWrapper<BinaryOperationExpression> self) =>
              self.toDart.span.toJS);

  UnsafeDartWrapper<BinaryOperationExpression> get toJS => toUnsafeWrapper;
}
