// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression.dart';
import '../../visitor/interface/expression.dart';

extension ExpressionToJS on Expression {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    Expression.bogus.toJS.constructor.superclass!.defineMethod(
        'accept'.toJS,
        ((UnsafeDartWrapper<Expression> self,
                ExternalDartReference<ExpressionVisitor<JSAny?>> visitor) =>
            self.toDart.accept(visitor.toDartObject)).toJSCaptureThis);
  }

  UnsafeDartWrapper<Expression> get toJS => toUnsafeWrapper;
}
