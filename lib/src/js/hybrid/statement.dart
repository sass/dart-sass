// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../ast/sass/statement.dart';
import '../../ast/sass/statement/extend_rule.dart';
import '../../util/span.dart';
import '../../visitor/interface/statement.dart';

extension StatementToJS on Statement {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    ExtendRule(Interpolation.bogus, bogusSpan)
        .toJS
        .constructor
        .superclass!
        .defineMethod(
            'accept'.toJS,
            ((UnsafeDartWrapper<Statement> self,
                    ExternalDartReference<StatementVisitor<JSAny?>> visitor) =>
                self.toDart.accept(visitor.toDartObject)).toJSCaptureThis);
  }

  UnsafeDartWrapper<Statement> get toJS => toUnsafeWrapper;
}
