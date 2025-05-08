// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression.dart';
import '../../ast/sass/interpolation.dart';
import '../../util/span.dart';
import '../../visitor/interface/expression.dart';

extension type JSExpression._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    Expression.bogus.toJS.constructor.superclass
      .defineMethod('accept'.toJS, ((JSExpression self, ExternalDartReference<ExpressionVisitor<JSAny?>> visitor) => self.toDart.accept(visitor.toDartObject)).toJS);
  }

  Expression get toDart => this as Expression;
}

extension ExpressionToJS on Expression {
  JSExpression get toJS => this as JSExpression;
}
