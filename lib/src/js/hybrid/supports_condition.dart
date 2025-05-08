// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression.dart';
import '../../ast/sass/interpolation.dart';
import '../../ast/sass/supports_condition.dart';
import '../../ast/sass/supports_condition/anything.dart';
import '../../ast/sass/supports_condition/declaration.dart';
import '../../ast/sass/supports_condition/function.dart';
import '../../ast/sass/supports_condition/interpolation.dart';
import '../../ast/sass/supports_condition/negation.dart';
import '../../ast/sass/supports_condition/operation.dart';
import '../../util/span.dart';
import 'interpolation.dart';

extension SupportsConditionToJS on SupportsCondition {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    // Because [SupportsCondition] is an interface rather than a superclass, we
    // have to define the method on each type individually.
    var anything = SupportsAnything(Interpolation.bogus, bogusSpan);
    for (var node in [
      anything,
      SupportsDeclaration(Expression.bogus, Expression.bogus, bogusSpan),
      SupportsFunction(Interpolation.bogus, Interpolation.bogus, bogusSpan),
      SupportsInterpolation(Expression.bogus, bogusSpan),
      SupportsNegation(anything, bogusSpan),
      SupportsOperation(anything, anything, "and", bogusSpan),
    ]) {
      node.toJS.constructor.defineMethod(
        'toInterpolation'.toJS,
        ((UnsafeDartWrapper<SupportsCondition> self) =>
            self.toDart.toInterpolation().toJS).toJSCaptureThis,
      );
    }
  }

  UnsafeDartWrapper<SupportsCondition> get toJS => toUnsafeWrapper;
}
