// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/argument_list.dart';
import '../../ast/sass/expression/function.dart';
import '../../util/span.dart';
import 'argument_list.dart';

extension FunctionExpressionToJS on FunctionExpression {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    FunctionExpression('a', ArgumentList.bogus, bogusSpan)
        .toJS
        .constructor
        .defineGetter(
            'arguments'.toJS,
            (UnsafeDartWrapper<FunctionExpression> self) =>
                self.toDart.arguments.toJS);
  }

  UnsafeDartWrapper<FunctionExpression> get toJS => toUnsafeWrapper;
}
